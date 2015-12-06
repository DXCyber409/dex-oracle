
class Plugin
  module CommonRegex
    CONST_NUMBER = 'const(?:\/\d+) [vp]\d+, (-?0x[a-f\d]+)'
    ESCAPE_STRING = '"(.*?)(?<!\\\\)"'
    CONST_STRING = 'const-string [vp]\d+, ' << ESCAPE_STRING << '.*'
    MOVE_RESULT_OBJECT = 'move-result-object ([vp]\d+)'
  end

  @plugins = []

  def self.plugins
    @plugins
  end

  def self.init_plugins(include_types, exclude_types)
    Object.constants.each do |klass|
      const = Kernel.const_get(klass)
      next unless const.respond_to?(:superclass) && const.superclass == Plugin
      @plugins << const
    end
  end

  # method_to_target_to_context -> { method: [target_to_context] }
  # target_to_context -> [ [target, context] ]
  # target = Driver.make_target, has :id key
  # context = [ [original, out_reg] ]
  def self.apply_batch(driver, method_to_target_to_contexts, modifier)
    all_batches = method_to_target_to_contexts.values.collect { |e| e.keys }.flatten
    return false if all_batches.empty?

    target_id_to_output = driver.run_batch(all_batches)
    apply_outputs(target_id_to_output, method_to_target_to_contexts, modifier)
  end

  # target_id_to_output -> { id: [status, output] }
  # status = (success|failure)
  def self.apply_outputs(target_id_to_output, method_to_target_to_contexts, modifier)
    made_changes = false
    method_to_target_to_contexts.each do |method, target_to_contexts|
      target_to_contexts.each do |target, contexts|
        status, output = target_id_to_output[target[:id]]
        unless status == 'success'
          logger.warn(output)
          next
        end

        contexts.each do |original, out_reg|
          modification = modifier.call(original, output, out_reg)
          #puts "modification #{original.inspect} = #{modification.inspect}"

          # Go home Ruby, you're drunk.
          p modification
          modification.gsub!('\\') { '\\\\' }
          method.body.gsub!(original) { modification }
        end

        made_changes = true
        method.modified = true
      end
    end

    made_changes
  end
end
