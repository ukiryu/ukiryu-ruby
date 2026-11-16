# frozen_string_literal: true

module Ukiryu
  # Sends one request to the core and raises a failed reply as the exception
  # the original gem raises: the class named by the reply's +source_class+,
  # with the core's message. A failure with no Ruby class (a transport code
  # such as INVALID_REQUEST or NOT_PORTED) stays an Ukiryu::Ffi::WireError.
  # The wire error is kept as the exception's #cause.
  module Bridge
    module_function

    # The decoded value of a successful reply.
    def request(request)
      Ffi.request(request)
    rescue Ffi::WireError => e
      raise exception_for(e)
    end

    # A whole reply object, for ops whose payload is not under "value".
    def reply(request)
      reply = Ffi.call(request)
      return reply if reply["ok"] == true

      raise exception_for(Ffi::WireError.from_reply(reply))
    end

    def exception_for(error)
      klass = exception_class(error.source_class)
      klass ? klass.new(error.message) : error
    end

    def exception_class(name)
      return nil unless name.is_a?(String) && !name.empty?

      klass = Object.const_get(name)
      klass.is_a?(Class) && klass <= Exception ? klass : nil
    rescue NameError
      nil
    end
  end
end
