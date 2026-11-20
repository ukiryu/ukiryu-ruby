# frozen_string_literal: true

module Ukiryu
  # Ruby references stay here; the core's existing cache decides LRU and TTL.
  # The snapshot contains only opaque IDs and timestamps, so neither tier needs
  # global handles or a second implementation of cache policy.
  class Cache
    attr_reader :max_size, :ttl

    def initialize(max_size: 100, ttl: nil, thread_safe: true)
      @max_size, @ttl = max_size, ttl
      @mutex = Mutex.new if thread_safe
      @state = []
      @ids = {}
      @objects = {}
      @next_id = 0
    end

    def [](key)
      synchronize { object_for(operate("get", key: @ids.fetch(key, 0))) }
    end

    def []=(key, value)
      synchronize do
        id = @ids[key] ||= (@next_id += 1)
        @objects[id] = [key, value]
        operate("set", key: id)
        value
      end
    end

    def key?(key)
      synchronize { operate("contains_key", key: @ids.fetch(key, 0)) }
    end

    def delete(key)
      synchronize do
        value = object_for(@ids[key])
        operate("delete", key: @ids.fetch(key, 0))
        value
      end
    end

    def clear
      synchronize { operate("clear"); {} }
    end

    def size
      synchronize { @state.size }
    end

    def empty?
      size.zero?
    end

    def keys
      synchronize { operate("keys").map { |id| @objects.fetch(id).first } }
    end

    def stats
      synchronize do
        result = operate("stats").transform_keys(&:to_sym)
        result[:ttl] = ttl
        result
      end
    end

    private

    def object_for(id)
      @objects[id]&.last
    end

    def synchronize(&block)
      @mutex ? @mutex.synchronize(&block) : yield
    end

    def operate(method, **args)
      reply = Bridge.reply("op" => "cache", "max_size" => max_size,
                           "ttl" => ttl, "now" => Time.now.to_f,
                           "state" => @state, "action" => { "method" => method }.merge(args))
      reply = reply.fetch("value")
      @state = reply.fetch("state")
      retained = @state.to_h { |id, _, _| [id, true] }
      @objects.delete_if { |id, _| !retained.key?(id) }
      @ids.delete_if { |_, id| !retained.key?(id) }
      reply.fetch("result")
    end
  end
end
