class ApplicationViewModel
  class << self
    def expose(*attrs, &block)
      if block
        raise ArgumentError, "expose with a block requires exactly one attr name" unless attrs.size == 1
        attr = attrs.first
        define_method(attr, &block)
        record_exposed(attr)
      else
        attrs.each do |attr|
          define_method(attr) { @record.public_send(attr) }
          record_exposed(attr)
        end
      end
    end

    def exposed_attrs
      (@exposed_attrs || []).dup.freeze
    end

    private

    def record_exposed(attr)
      @exposed_attrs = (@exposed_attrs || []) + [ attr ]
    end
  end

  def initialize(record)
    @record = record
  end

  def to_h
    self.class.exposed_attrs.each_with_object({}) do |attr, h|
      h[attr] = render_value(public_send(attr))
    end
  end

  private

  def render_value(value)
    case value
    when ApplicationViewModel then value.to_h
    when Array                then value.map { |v| render_value(v) }
    else                           value
    end
  end
end
