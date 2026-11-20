# frozen_string_literal: true

module Ukiryu
  module ToolCache
    class << self
      def cache
        @cache ||= Cache.new(max_size: 50, ttl: 3600)
      end

      def get(key)
        cache[key]
      end

      def set(key, tool)
        cache[key] = tool
      end

      def cache_key_for(name, options)
        result = Bridge.request("op" => "cache", "max_size" => 50, "ttl" => 3600,
                                "now" => Time.now.to_f, "state" => [], "action" => {
                                  "method" => "tool_key", "name" => name.to_s,
                                  "platform" => (options[:platform] || Host.platform).to_s,
                                  "shell" => (options[:shell] || Host.shell).to_s,
                                  "version" => options[:version] ? options[:version].to_s : nil
                                })
        result.fetch("result")
      end

      def clear
        cache.clear
        Tools::Generator.clear_cache
      end

      def clear_definition_cache
        Definition::Loader.clear_cache
      end
    end
  end
end
