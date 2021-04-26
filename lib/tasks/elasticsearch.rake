# frozen_string_literal: true

namespace :elasticsearch do
  task :create_index do
    model_klass_name = ENV.fetch('CLASS_NAME')
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

    resp = Unity::Utils::ElasticSearchService.instance.create_index(
      index: versioned_index_name,
      body: index_configuration
    )
    unless resp['acknowledged'] == true
      pp resp
      abort "Unable to create index: #{versioned_index_name}"
    end

    puts "Index '#{versioned_index_name}' created successfully"
  end

  task :import do
    Unity.concurrency = 1

    model_klass_name = ENV.fetch('CLASS_NAME')
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

    indexes_with_alias = Unity::Utils::ElasticSearchService.instance.checkout do |conn|
      res = conn.indices.get_alias(name: index_name)
      res.keys
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      []
    end

    begin
      resp = Unity::Utils::ElasticSearchService.instance.create_index(
        index: versioned_index_name,
        body: index_configuration
      )
      unless resp['acknowledged'] == true
        pp resp
        abort "Unable to create index: #{versioned_index_name}"
      end
    rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
      unless e.message.include?('resource_already_exists_exception')
        abort "an error has occured when creating the index: #{e.message}"
      end
    end

    model_klass.all.each_slice(25) do |items|
      Unity::Utils::ElasticSearchService.instance.bulk(
        index: versioned_index_name,
        body: items.collect do |item|
          {
            'index' => {
              '_id' => item.as_indexed_id, 'data' => item.as_indexed_json
            }
          }
        end
      )
    end

    Unity::Utils::ElasticSearchService.instance.checkout do |conn|
      update_aliases_actions = []
      indexes_with_alias.each do |item|
        update_aliases_actions.push(
          { 'remove' => { 'index' => item, 'alias' => index_name } }
        )
      end
      update_aliases_actions.push(
        {
          'add' => {
            'index' => versioned_index_name, 'alias' => index_name
          }
        }
      )

      conn.indices.update_aliases(body: { 'actions' => update_aliases_actions })
    end
  end
end
