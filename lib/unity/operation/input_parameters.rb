# frozen_string_literal: true

module Unity
  class Operation
    class InputParameters
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::AttributeMethods
      include ActiveModel::Validations
      include ActiveModel::Serialization
      include ActiveModel::Serializers::JSON
    end
  end
end
