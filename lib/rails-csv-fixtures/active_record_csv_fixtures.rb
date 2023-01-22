require 'csv'
require 'erb'

module RailsCsvFixtures
  module CsvFixtures
    extend ActiveSupport::Concern

    included do
      alias_method :read_fixture_files_without_csv_support, :read_fixture_files
      alias_method :read_fixture_files, :read_fixture_files_with_csv_support
    end

    def read_fixture_files_with_csv_support(*args)
      if ::File.file?(csv_file_path(*args))
        read_csv_fixture_files(*args)
      else
        read_fixture_files_without_csv_support(*args)
      end
    end

    def read_csv_fixture_files(*args)
      fixtures = fixtures() || {}
      json_converter = proc { |v| JSON.parse(v) rescue v }
      reader = CSV.parse(erb_render(IO.read(csv_file_path(*args))), converters: json_converter)
      header = reader.shift
      i = 0
      reader.each do |row|
        data = {}
        row.each_with_index do |cell, j|
          unless cell.nil?
            cell = cell.to_s.strip unless cell.is_a?(Hash)
            data[header[j].to_s.strip] = cell
          end
        end
        class_name = (args.second || model_class && model_class.name)
        label = data['_label'] || "#{class_name.to_s.underscore}_#{i+=1}"
        data.delete '_label'
        fixtures[label] = ActiveRecord::Fixture.new(data, model_class)
      end
      fixtures
    end

    def csv_file_path(*args)
      (args.first || @path || @fixture_path) + '.csv'
    end

    def erb_render(fixture_content)
      ERB.new(fixture_content).result
    end
  end
end

require 'active_record/fixtures'
if ::ActiveRecord::VERSION::MAJOR < 4
  ::ActiveRecord::Fixtures.send :include, RailsCsvFixtures::CsvFixtures
else
  ::ActiveRecord::FixtureSet.send :include, RailsCsvFixtures::CsvFixtures
end
