module ZendeskAPI
  module Save
    include ResponseHandler

    # If this resource hasn't been deleted, then create or save it.
    # Executes a POST if it is a {Data#new_record?}, otherwise a PUT.
    # Merges returned attributes on success.
    # @return [Boolean] Success?
    def save!(options = {})
      return false if respond_to?(:destroyed?) && destroyed?

      save_associations

      @response = @client.connection.public_send(save_method, path) do |req|
        req.body = attributes_for_save.merge(@global_params)

        yield req if block_given?
      end

      handle_response(@response)

      attributes.clear_changes
      clear_associations

      true
    end

    # Saves, returning false if it fails and attaching the errors
    def save(options = {}, &block)
      save!(options, &block)
    rescue ZendeskAPI::Error::RecordInvalid => e
      @errors = e.errors
      false
    rescue ZendeskAPI::Error::ClientError
      false
    end

    # Removes all cached associations
    def clear_associations
      self.class.associations.each do |association_data|
        name = association_data[:name]
        instance_variable_set("@#{name}", nil) if instance_variable_defined?("@#{name}")
      end
    end

    # Saves associations
    # Takes into account inlining, collections, and id setting on the parent resource.
    def save_associations
      self.class.associations.each do |association_data|
        association_name = association_data[:name]

        next unless send("#{association_name}_used?") && association = send(association_name)

        inline_creation = association_data[:inline] == :create && new_record?
        changed = association.is_a?(Collection) || association.changed?

        if association.respond_to?(:save) && changed && !inline_creation && association.save
          self.send("#{association_name}=", association) # set id/ids columns
        end

        if (association_data[:inline] == true || inline_creation) && changed
          attributes[association_name] = association.to_param
        end
      end
    end

    protected

    def save_method
      if new_record?
        :post
      else
        :put
      end
    end
  end
end
