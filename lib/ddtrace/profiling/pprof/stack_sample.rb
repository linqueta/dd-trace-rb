require 'forwardable'

require 'ddtrace/ext/profiling'
require 'ddtrace/profiling/events/stack'
require 'ddtrace/profiling/pprof/converter'

module Datadog
  module Profiling
    module Pprof
      # Builds a profile from a StackSample
      class StackSample
        include Pprof::Converter
        extend Forwardable

        def initialize(builder)
          @builder = builder
          @sample_type_indexes = {}
        end

        def add_events!(stack_samples)
          add_samples!(stack_samples)
        end

        def add_sample_types!
          @sample_type_indexes = super(
            wall_time_ns: [
              Ext::Profiling::Pprof::VALUE_TYPE_WALL,
              Ext::Profiling::Pprof::VALUE_UNIT_NANOSECONDS
            ]
          )
        end

        def add_samples!(stack_samples)
          samples = build_samples(stack_samples)
          samples.concat(samples)
        end

        def build_samples(stack_samples)
          groups = group_events(stack_samples, &method(:stack_sample_group_key))
          groups.collect do |_group_key, group|
            build_sample(group.sample, group.values)
          end
        end

        def stack_sample_group_key(stack_sample)
          [
            stack_sample.thread_id,
            [
              stack_sample.frames.collect(&:to_s),
              stack_sample.total_frame_count
            ]
          ].hash
        end

        def build_sample(stack_sample, values)
          locations = builder.build_locations(
            stack_sample.frames,
            stack_sample.total_frame_count
          )

          Perftools::Profiles::Sample.new(
            location_id: locations.collect(&:id), # TODO: Lazy enumerate?
            value: values,
            label: build_sample_labels(stack_sample)
          )
        end

        def build_sample_values(stack_sample)
          # If we can't get an index for a sample type, it probably hasn't been defined.
          # We won't be able to put its value at the correct index.
          raise UnknownSampleTypeIndex(:wall_time_ns) unless @sample_type_indexes[:wall_time_ns]

          # Build a value array that matches the length of the sample types
          # Populate all values with "no value" by default
          values = Array.new(sample_types.length, Builder::SAMPLE_VALUE_NO_VALUE)

          # Add values at appropriate index.
          # There may be other sample types present; be sure to put this value
          # matching the correct index of the actual sample type we want to match.
          values[@sample_type_indexes[:wall_time_ns]] = stack_sample.wall_time_interval_ns
          values
        end

        def build_sample_labels(stack_sample)
          [
            Perftools::Profiles::Label.new(
              key: string_table.fetch(Ext::Profiling::Pprof::LABEL_KEY_THREAD_ID),
              str: string_table.fetch(stack_sample.thread_id.to_s)
            )
          ]
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
