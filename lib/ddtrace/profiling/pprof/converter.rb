require 'forwardable'
require 'ddtrace/ext/profiling'

module Datadog
  module Profiling
    module Pprof
      # Helper functions for modules that convert events to pprof
      class Converter
        extend Forwardable

        attr_reader \
          :builder

        def_delegators \
          :builder,
          :functions,
          :locations,
          :mappings,
          :sample_types,
          :samples,
          :string_table

        def initialize(builder)
          @builder = builder
        end

        def group_events(events)
          # Event grouping in format:
          # [key, (event, [values, ...])]
          event_groups = {}

          events.each do |event|
            key = yield(event)
            values = build_sample_values(event)

            unless key.nil?
              if event_groups.key?(key)
                # Update values for group
                group_values = event_groups[key].values
                group_values.each_with_index do |group_value, i|
                  group_values[i] = group_value + values[i]
                end
              else
                # Add new group
                event_groups[key] = EventGroup.new(event, values)
              end
            end
          end

          event_groups
        end

        def sample_value_types
          raise NotImplementedError
        end

        def add_events!(events)
          raise NotImplementedError
        end

        def build_sample_values(stack_sample)
          # Build a value array that matches the length of the sample types
          # Populate all values with "no value" by default
          Array.new(sample_types.length, Ext::Profiling::Pprof::SAMPLE_VALUE_NO_VALUE)
        end

        EventGroup = Struct.new(:sample, :values)
      end
    end
  end
end
