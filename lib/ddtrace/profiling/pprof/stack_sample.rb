require 'ddtrace/ext/profiling'
require 'ddtrace/profiling/events/stack'
require 'ddtrace/profiling/pprof/converter'

module Datadog
  module Profiling
    module Pprof
      # Builds a profile from a StackSample
      class StackSample < Converter
        def add_events!(stack_samples)
          add_samples!(stack_samples)
        end

        def sample_value_types
          {
            wall_time_ns: [
              Ext::Profiling::Pprof::VALUE_TYPE_WALL,
              Ext::Profiling::Pprof::VALUE_UNIT_NANOSECONDS
            ]
          }
        end

        def add_samples!(stack_samples)
          new_samples = build_samples(stack_samples)
          samples.concat(new_samples)
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
          values = super(stack_sample)

          # Add values at appropriate index.
          # There may be other sample types present; be sure to put this value
          # matching the correct index of the actual sample type we want to match.
          values[builder.sample_type_index(:wall_time_ns)] = stack_sample.wall_time_interval_ns
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
      end
    end
  end
end
