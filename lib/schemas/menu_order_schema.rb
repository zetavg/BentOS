# frozen_string_literal: true

module MenuOrderSchema
  SCHEMA_FILE_PATH = Rails.root.join('schemas', 'menu-order-schema.json')
  SCHEMA_FILE_CONTENTS = File.read(SCHEMA_FILE_PATH)

  def self.schema
    @schema ||= JSON.parse(SCHEMA_FILE_CONTENTS)
  end
end
