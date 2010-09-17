module StatePermissions
  
  def self.name_of_perms(klass)
    "state_permission_checks On #{klass.to_s}"
  end
  
  class StatePermissionDefiner
    def initialize(klass)
      @klass = klass
      @allowed_from_states = []
      @allowed_to_states = []
      @permit_blocks = []
      @deny_blocks = []      
    end
    
    def from_range(a, b)
      while(a && a.is_before?(b))
        from(a)
        a = a.next_state
      end
      from(b)
    end
    
    def from(state)
      @allowed_from_states << state
    end
    
    def to_range(a, b)
      while(a && a.is_before?(b))
        to(a)
        a = a.next_state
      end
      to(b)
    end
    
    def to(state)
      @allowed_to_states << state
    end
    
    def state(named)
      @klass.state(named)
    end

    def state_after(named)
      @klass.state_after(named)
    end

    def state_before(named)
      @klass.state_before(named)
    end
    
    def deny_all
    end
    
    def also_permit_if(&block)
      @permit_blocks << block
    end
    
    def always_deny_if(&block)
      @deny_blocks << block      
    end
    
    def allowed_from_to?(kase, from_state, to_state)
      # puts "checking state from and to #{from_state} #{to_state}"
      
      result = false
      unless to_state.is_a?(StateWorkflow::State)
        to_state = @klass.state(to_state.to_sym)
      end
      if from_state.blank?
        result ||= @allowed_to_states.include?(to_state)
      else
        unless from_state.is_a?(StateWorkflow::State)
          from_state = @klass.state(from_state.to_sym)
        end
        result ||= (@allowed_from_states.include?(from_state) && @allowed_to_states.include?(to_state))
      end
      @permit_blocks.each do |permit_block|
        result ||= permit_block.call(kase, from_state, to_state)
      end
      @deny_blocks.each do |deny_blocks|
        if deny_blocks.call(kase, from_state, to_state)
          result = false
        end
      end
      
      # puts "Result #{result}"
      
      result
    end
  end
  
  mattr_accessor :state_permission_defaults
  self.state_permission_defaults ||= {}
  
  def self.included(base)
    base.class_eval do
      # mattr_accessor :state_permission_checks
      # # mattr_accessor :state_permit_changes_from_list
      # # mattr_accessor :state_permit_changes_to_list
      
      def self.default_state_changes_on(*args, &block)
        args.each do |klass|
          perms_name = StatePermissions.name_of_perms(klass)
          StatePermissions.state_permission_defaults[perms_name] = block
        end
        permit_state_changes_on(*args, &block)
      end
      
      def self.permit_state_changes_on(*args, &block)
        args.each do |klass|
          # checker = StatePermissionChecker.new
          definer = StatePermissionDefiner.new(klass)
          perms_name = StatePermissions.name_of_perms(klass)
          begin
            definer.instance_eval(&block)
          rescue => e
            puts "state change permissions definition problem:"
            puts e.inspect
            puts e.backtrace.join("\n")
          end
          if defaults = StatePermissions.state_permission_defaults[perms_name]
            definer.instance_eval(&defaults)
          end
          permitted_objects_for(perms_name) do |kase, from_state, to_state|            
            definer.allowed_from_to?(kase, from_state, to_state)
          end
        end
      end
      
    end
    # base.state_permission_checks = {}
  end
  
end