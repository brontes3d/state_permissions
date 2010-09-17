module ProtectStateChanges
  
  def self.included(base)
    base.class_eval do
      before_save :check_permissions_for_changed_states
    end
  end
  
  def allowed_to_change_state_to?(to_state, from_state = self.state)
    return true unless ProtectedModel.model_proctection_on?
    
    # puts "can I can move from #{from_state} to #{to_state}"      
    
    perms = AuthorizedActor.current_actor.permissions
    perms_proc = perms.get_permitted_object_proc(StatePermissions.name_of_perms(self.class))
    if perms_proc
      perms_proc.call(self, from_state, to_state)
    else
      AuthorizedActor.current_actor.permission_undefined do
        raise DefinePermissions::PermissionNotDefined.new("no state change permissions for #{self.class} defined on #{perms}")
      end
    end
  end
  
  def check_permissions_for_changed_states
    return unless ProtectedModel.model_proctection_on?

    if self.changes && self.changes["state"]
      from_state, to_state = self.changes["state"]      
      unless allowed_to_change_state_to?(to_state, from_state)
        raise SecurityError.new("#{AuthorizedActor.current_actor} permission denied to change state on #{self} from #{from_state.inspect} to #{to_state.inspect}")                    
      end
    end
  end
  
end
