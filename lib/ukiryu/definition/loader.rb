# frozen_string_literal: true

module Ukiryu
  module Definition
    # Ukiryu::Definition::Loader of the original, reduced to its cache API.
    #
    # Definitions are parsed by the core on every tool request, so the Ruby
    # side holds no parsed profiles and there is nothing to evict. The
    # original's load-time profile checks (validation: :strict, :lenient,
    # :none) need a core load op and are not applied yet.
    class Loader
      class << self
        def clear_cache(_source = nil)
          nil
        end
      end
    end
  end
end
