# frozen_string_literal: true

ElasticSearchIndexSpec = Struct.new(
  :model_klass, :name, :versioned_name, :configuration
)

def elasticsearch_model_index_spec_for(model_klass_name)
  model_klass_name_split = model_klass_name.split('::')
  model_klass = Kernel
  model_klass_name_split.each do |model_klass_name_split_part|
    model_klass = model_klass.const_get(model_klass_name_split_part)
  end
  index_name = model_klass.const_get(:SEARCH_INDEX_NAME)
  versioned_index_name = ENV.fetch(
    'VERSIONED_INDEX_NAME', index_name + "-#{Time.now.strftime('%Y%m%d%H%M%S')}"
  )
  index_configuration = \
    if model_klass.respond_to?(:search_index_configuration)
      model_klass.search_index_configuration
    else
      {}
    end

  ElasticSearchIndexSpec.new(
    model_klass, index_name, versioned_index_name, index_configuration
  )
end

namespace :elasticsearch do
  task :create_index do
    index_spec = elasticsearch_model_index_spec_for(ENV.fetch('CLASS_NAME'))
    if ENV.key?('VERSIONED_INDEX_NAME')
      index_spec.versioned_name = ENV.fetch('VERSIONED_INDEX_NAME')
    end

    resp = Unity::Utils::ElasticSearchService.instance.create_index(
      index: index_spec.versioned_name,
      body: index_spec.configuration
    )
    unless resp['acknowledged'] == true
      pp resp
      abort "Unable to create index: #{index_spec.versioned_name}"
    end

    puts "|> Index '#{index_spec.versioned_name}' created successfully"

    if ENV.fetch('CONFIGURE_ALIAS', 'n').to_s.downcase == 'y'
      ENV['VERSIONED_INDEX_NAME'] = index_spec.versioned_name
      Rake::Task['elasticsearch:configure_alias'].invoke
    end
  end

  task :configure_alias do
    index_spec = elasticsearch_model_index_spec_for(ENV.fetch('CLASS_NAME'))
    index_spec.versioned_name = ENV.fetch('VERSIONED_INDEX_NAME')

    indexes_with_alias = Unity::Utils::ElasticSearchService.instance.checkout do |conn|
      res = conn.indices.get_alias(name: index_spec.name)
      res.keys
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      []
    end

    Unity::Utils::ElasticSearchService.instance.checkout do |conn|
      update_aliases_actions = []
      indexes_with_alias.each do |item|
        update_aliases_actions.push(
          { 'remove' => { 'index' => item, 'alias' => index_spec.name } }
        )
      end
      update_aliases_actions.push(
        {
          'add' => {
            'index' => index_spec.versioned_name, 'alias' => index_spec.name
          }
        }
      )

      conn.indices.update_aliases(body: { 'actions' => update_aliases_actions })
    end

    puts "|> Configure alias '#{index_spec.name}' on '#{index_spec.versioned_name}'"
  end

  task :import do
    Unity.concurrency = 1

    index_spec = elasticsearch_model_index_spec_for(ENV.fetch('CLASS_NAME'))
    index_spec.versioned_name = ENV.fetch('VERSIONED_INDEX_NAME')

    processed_count = 0
    index_spec.model_klass.all.each_slice(100) do |items|
      Unity::Utils::ElasticSearchService.instance.bulk(
        index: index_spec.versioned_name,
        body: items.collect do |item|
          {
            'index' => {
              '_id' => item.as_indexed_id, 'data' => item.as_indexed_json
            }
          }
        end
      )
      processed_count += items.length
      print "|> #{processed_count} imported                                   \r"
    end

    puts "|> Import finished, #{processed_count} documents indexed."
  end

  task :rebuild do
    index_spec = elasticsearch_model_index_spec_for(ENV.fetch('CLASS_NAME'))
    ENV['VERSIONED_INDEX_NAME'] = index_spec.versioned_name

    puts "|> Using versioned index name: #{index_spec.versioned_name}"
    Rake::Task['elasticsearch:create_index'].invoke
    Rake::Task['elasticsearch:import'].invoke
    Rake::Task['elasticsearch:configure_alias'].invoke
  end
end
