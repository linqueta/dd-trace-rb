require 'forwardable'

module Datadog
  module Profiling
    module Pprof
      # Helper functions for modules that convert events to pprof
      module Converter
        extend Forwardable

        attr_reader :builder

        def_delegators \
          :builder,
          :functions,
          :locations,
          :mappings,
          :sample_types,
          :samples,
          :string_table

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

        # Creates and add sample types, returning the index of each type.
        def add_sample_types!(types)
          types.map do |type_name, type_args|
            index = nil

            sample_type = sample_types.fetch(*type_args) do |id, type, unit|
              index = id
              builder.build_value_type(type, unit)
            end

            # Map the type to the index to which its assigned.
            [type_name, index || sample_types.messages.index(sample_type)]
          end.to_h
        end

        def build_sample_values(event)
          raise NotImplementedError
        end

        EventGroup = Struct.new(:sample, :values)
      end
    end
  end
end
