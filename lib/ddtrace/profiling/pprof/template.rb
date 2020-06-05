require 'ddtrace/profiling/pprof/message_set'
require 'ddtrace/profiling/pprof/builder'

require 'ddtrace/profiling/events/stack'

require 'ddtrace/profiling/pprof/pprof_pb'
require 'ddtrace/profiling/pprof/stack_sample'

module Datadog
  module Profiling
    module Pprof
      # Converts a collection of profiling events into a Perftools::Profiles::Profile
      class Template
        CONVERTERS = {
          Events::StackSample => Pprof::StackSample
        }.freeze

        attr_reader \
          :builder,
          :converters,
          :mappings,
          :sample_types,
          :sample_type_mappings

        def self.for_event_classes(event_classes)
          # Build a map of event class --> converter class
          mappings = event_classes.each_with_object({}) do |event_class, m|
            converter_class = CONVERTERS[event_class]
            raise NoProfilingEventConversionError, event_class unless converter_class
            m[event_class] = converter_class
          end

          new(mappings)
        end

        def initialize(mappings)
          @builder = Builder.new
          @converters = Hash.new { |hash, event_class| raise NoProfilingEventConversionError, event_class }
          @mappings = mappings
          @sample_types = MessageSet.new
          @sample_type_mappings = {}

          # Combine all sample types from each converter class
          types = mappings.values.each_with_object({}) do |converter_class, types|
            types.merge!(converter_class.sample_value_types)
          end

          # Build the sample types into sample type objects
          types.each do |type_name, type_args|
            index = nil

            sample_type = builder.sample_types.fetch(*type_args) do |id, type, unit|
              index = id
              builder.build_value_type(type, unit)
            end

            # Create mapping between the type and index to which its assigned.
            # Do this for faster lookup while building profile sample values.
            sample_type_mappings[type_name] = index || builder.sample_types.messages.index(sample_type)
          end

          # Freeze them so they can't be modified.
          # We don't want the number of sample types to vary between samples within the same profile.
          builder.sample_types.freeze
          sample_type_mappings.freeze

          # Add converters
          mappings.each do |event_class, converter_class|
            converters[event_class] = converter_class.new(builder, sample_type_mappings)
          end
        end

        def add_events!(event_class, events)
          converters[event_class].add_events!(events)
        end

        def to_profile
          @profile ||= builder.build_profile
        end

        # Error when an unknown event type is given to be converted
        class NoProfilingEventConversionError < ArgumentError
          attr_reader :type

          def initialize(type)
            @type = type
          end

          def message
            "Profiling event type '#{type}' cannot be converted to pprof."
          end
        end
      end
    end
  end
end
