require 'ddtrace/profiling/flush'
require 'ddtrace/profiling/pprof/message_set'
require 'ddtrace/profiling/pprof/string_table'

require 'ddtrace/profiling/pprof/pprof_pb'
require 'ddtrace/profiling/pprof/stack_sample'

module Datadog
  module Profiling
    module Pprof
      # Generic profile building behavior
      class Builder
        DESC_FRAME_OMITTED = 'frame omitted'.freeze
        DESC_FRAMES_OMITTED = 'frames omitted'.freeze

        CONVERTERS = {
          Events::StackSample => Pprof::StackSample
        }.freeze

        attr_reader \
          :converters,
          :functions,
          :locations,
          :mappings,
          :sample_types,
          :samples,
          :string_table

        def initialize(converters)
          @profile = nil
          @sample_types = MessageSet.new
          @sample_type_indexes = {}
          @samples = []
          @mappings = []
          @locations = MessageSet.new
          @functions = MessageSet.new
          @string_table = StringTable.new

          # Build converters
          @converters = converters.map do |event_class, converter_class|
            [event_class, converter_class.new(self)]
          end.to_h

          # Add all sample types now, because they will be required
          # before adding events to the builder.
          # (Converters need to know the full list of sample types.)
          converter_sample_types = @converters.values.inject({}) do |types, converter|
            types.merge!(converter.sample_value_types)
          end

          build_sample_types(converter_sample_types)
          sample_types.freeze
        end

        def add_flush!(flush)
          converter = converters[flush.event_class]
          raise NoTypeConversionError, flush.event_class unless converter
          converter.add_events!(flush.events)
        end

        def to_profile
          @profile ||= build_profile
        end

        def build_profile
          @mappings = build_mappings

          Perftools::Profiles::Profile.new(
            sample_type: @sample_types.messages,
            sample: @samples,
            mapping: @mappings,
            location: @locations.messages,
            function: @functions.messages,
            string_table: @string_table.strings
          )
        end

        def build_sample_types(types)
          types.each do |type_name, type_args|
            index = nil

            sample_type = sample_types.fetch(*type_args) do |id, type, unit|
              index = id
              build_value_type(type, unit)
            end

            # Map the type to the index to which its assigned.
            @sample_type_indexes[type_name] = index || sample_types.messages.index(sample_type)
          end
        end

        def sample_type_index(type)
          index = @sample_type_indexes[type]
          raise UnknownSampleTypeIndex, type unless index
          index
        end

        def build_value_type(type, unit)
          Perftools::Profiles::ValueType.new(
            type: @string_table.fetch(type),
            unit: @string_table.fetch(unit)
          )
        end

        def build_locations(backtrace_locations, length)
          locations = backtrace_locations.collect do |backtrace_location|
            @locations.fetch(
              # Filename
              backtrace_location.path,
              # Line number
              backtrace_location.lineno,
              # Function name
              backtrace_location.base_label,
              # Build function
              &method(:build_location)
            )
          end

          omitted = length - backtrace_locations.length

          # Add placeholder stack frame if frames were truncated
          if omitted > 0
            desc = omitted == 1 ? DESC_FRAME_OMITTED : DESC_FRAMES_OMITTED
            locations << @locations.fetch(
              '',
              0,
              "#{omitted} #{desc}",
              &method(:build_location)
            )
          end

          locations
        end

        def build_location(id, filename, line_number, function_name = nil)
          Perftools::Profiles::Location.new(
            id: id,
            line: [build_line(
              @functions.fetch(
                filename,
                function_name,
                &method(:build_function)
              ).id,
              line_number
            )]
          )
        end

        def build_line(function_id, line_number)
          Perftools::Profiles::Line.new(
            function_id: function_id,
            line: line_number
          )
        end

        def build_function(id, filename, function_name)
          Perftools::Profiles::Function.new(
            id: id,
            name: @string_table.fetch(function_name),
            filename: @string_table.fetch(filename)
          )
        end

        def build_mappings
          [
            Perftools::Profiles::Mapping.new(
              id: 1,
              filename: @string_table.fetch($PROGRAM_NAME)
            )
          ]
        end

        # Error when an unknown event type is given to be converted
        class NoTypeConversionError < ArgumentError
          attr_reader :type

          def initialize(type)
            @type = type
          end

          def message
            "Unknown profiling event type cannot be converted to pprof: #{type}"
          end
        end

        # Error when the index of a sample type is unknown
        class UnknownSampleTypeIndex < StandardError
          attr_reader :value

          def initialize(value)
            @value = value
          end

          def message
            "Sample value index for '#{value}' is unknown."
          end
        end
      end
    end
  end
end
