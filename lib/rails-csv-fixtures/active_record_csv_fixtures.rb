require 'csv'
require 'erb'

module RailsCsvFixtures
  module CsvFixtures
    extend ActiveSupport::Concern

    included do
      alias_method :read_fixture_files_without_csv_support, :read_fixture_files
      alias_method :read_fixture_files, :read_fixture_files_with_csv_support
    end

    def read_fixture_files_with_csv_support(path)
      csv_paths = Dir["#{path}{.csv,/{**,*}/*.csv}"].select { |f|
        ::File.file?(f)
      }

      # This duplicates (preempts) the Rails yml loading implementation ActiveRecord::FixtureSet::read_fixture_files
      yml_paths = Dir["#{path}{.yml,/{**,*}/*.yml}"].select { |f|
        ::File.file?(f)
      }

      raise ArgumentError, "No fixture files found for #{@name}" if yml_paths.empty? && csv_paths.empty?

      csv_fixtures = {}
      csv_fixtures = csv_paths.each_with_object({}) do |path, fixtures|
        fixtures.merge! read_csv_fixture_files(path)
      end

      yml_fixtures = yml_paths.each_with_object({}) do |path, fixtures|
        fixtures.merge! read_fixture_files_without_csv_support(Pathname(path).sub_ext('').to_s)
      end
      
      csv_fixtures.merge yml_fixtures
    end

    def read_csv_fixture_files(path)
      fixtures = {}
      json_converter = proc { |v| JSON.parse(v) rescue v }
      reader = CSV.parse(erb_render(IO.read path), converters: json_converter)
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
        self.model_class = default_fixture_model_class
        class_name = (model_class && model_class.name)
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
