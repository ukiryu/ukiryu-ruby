# frozen_string_literal: true

module Ukiryu
  # Per-Ractor storage for the gem's few pieces of mutable module state
  # (the chosen transport tier, the loaded ffi library, the Config instance
  # and the Tool cache).
  #
  # The main Ractor, and runtimes without Ractor such as TruffleRuby, keep
  # that state in the owning module's instance variables, as before. Other
  # Ractors cannot read those (they hold a Mutex or a Hash), so each one
  # builds its own copy in Ractor-local storage on first use. Nothing is
  # shared between Ractors: a value set in one is not seen in another.
  module RactorLocal
    module_function

    # True in the main Ractor, and on runtimes without Ractor.
    def main?
      !defined?(::Ractor) || ::Ractor.current == ::Ractor.main
    end

    # The current (non-main) Ractor's value for +key+, built by the block on
    # first use. Ruby 3.4+ builds it under the Ractor's own lock; older
    # Rubies use a plain read-then-write.
    def fetch(key, &build)
      return ::Ractor.store_if_absent(key, &build) if ::Ractor.respond_to?(:store_if_absent)

      ractor = ::Ractor.current
      ractor[key] ||= build.call
    end
  end
end
