module RailsAdmin

  # Rails Admin's history API.  All access to history data should go
  # through this module so users can patch it to use other history/audit
  # packages.
  class AbstractHistory

    # Create a history record for an update operation.
    def self.create_update_history(model, object, associations_before, associations_after, modified_associations, old_object, user)
      messages = []

      # determine which fields changed ???
      changed_property_list = []
      properties = model.properties.reject{|property| RailsAdmin::History::IGNORED_ATTRS.include?(property[:name])}

      properties.each do |property|
        property_name = property[:name].to_param
        if old_object.send(property_name) != object.send(property_name)
          changed_property_list << property_name
        end
      end

      model.associations.each do |t|
        assoc = changed_property_list.index(t[:child_key].to_param)
        if assoc
          changed_property_list[assoc] = "associated #{t[:pretty_name]}"
        end
      end

      # Determine if any associations were added or removed
      associations_after.each do |key, current|
        removed_ids = (associations_before[key] - current).map{|m| '#' + m.to_s}
        added_ids = (current - associations_before[key]).map{|m| '#' + m.to_s}
        if removed_ids.any?
          messages << "Removed #{key.to_s.capitalize} #{removed_ids.join(', ')} associations"
        end
        if added_ids.any?
          messages << "Added #{key.to_s.capitalize} #{added_ids.join(', ')} associations"
        end
      end

      modified_associations.uniq.each do |t|
        changed_property_list << "associated #{t}"
      end

      if not changed_property_list.empty?
        messages << "Changed #{changed_property_list.join(", ")}"
      end

      create_history_item(messages, object, model, user) unless messages.empty?
    end

    # Create a history item for any operation.
    def self.create_history_item(message, object, abstract_model, user)
      message = message.join(', ') if message.is_a? Array
      date = Time.now
      RailsAdmin::History.create(
                                 :message => message,
                                 :item => object.id,
                                 :table => abstract_model.pretty_name,
                                 :username => user ? user.email : "",
                                 :month => date.month,
                                 :year => date.year
                                 )
    end

    # Fetch the history items for a model.  Returns an array containing
    # the page count and an AR query result containing the history
    # items.
    def self.history_for_model(model, query, sort, sort_reverse, all, page, per_page = RailsAdmin::Config::Sections::List.default_items_per_page || 20)
      page ||= 1
      history = History.all(:table => model.pretty_name)

      if query
        history &= (
          History.all(:message.like  => "%#{query}%") |
          History.all(:username.like => "%#{query}%")
        )
      end

      if sort
        sort    = sort.to_sym
        sort    = sort.desc if sort_reverse == 'true'
        history = history.all(:order => [ sort ])
      end

      if all
        [1, history]
      else
        page_count = (history.count.to_f / per_page).ceil
        [page_count, history.all(:limit => per_page, :offset => (page.to_i - 1) * per_page)]
      end
    end

    # Fetch the history items for a specific object instance.
    def self.history_for_object(model, object, query, sort, sort_reverse)
      history = History.all(:table => model.pretty_name, :item => object.id)

      if query
        history &= (
          History.all(:message.like  => "%#{query}%") |
          History.all(:username.like => "%#{query}%")
        )
      end

      if sort
        sort    = sort.to_sym
        sort    = sort.desc if sort_reverse == 'true'
        history = history.all(:order => [ sort ])
      end

      history
    end

    # Fetch the history item counts for a 5-month period.  Ref=0 ends at
    # the present month, ref=-1 is the block before that, etc.
    def self.history_summaries(ref)
      current_diff = -5 * ref
      start_month = (5 + current_diff).month.ago.month
      start_year = (5 + current_diff).month.ago.year
      stop_month = (current_diff).month.ago.month
      stop_year = (current_diff).month.ago.year

      # try to be helpful if the user hasn't run the history table
      # rename generator.  this happens to be the first spot that will
      # cause a problem.
      # FIXME: at some point, after a reasonable transition period,
      # we can remove the rescue, etc.
      begin
        RailsAdmin::History.get_history_for_dates(start_month, stop_month, start_year, stop_year)
      rescue RailsAdmin::History::QueryError => e
        message = if e.message.include?('rails_admin_histories') # seems to be the only common text in the db-specific error messages
          "Please run the generator \"rails generate rails_admin:install_admin\" then migrate your database.  #{e.message}"
        else
          e.message
        end
        raise e.class, message, e.backtrace
      end
    end


    # Fetch the history item counts for the most recent 5 months.
    def self.history_latest_summaries
      self.history_summaries(0)
    end

    # Fetch detailed history for one month.
    def self.history_for_month(ref, section)
      current_ref = -5 * ref.to_i
      current_diff = current_ref + 5 - (section.to_i + 1)

      current_month = current_diff.month.ago

      return History.all(:month => current_month.month, :year => current_month.year), current_month
    end

    # Fetch the most recent history item for a model.
    def self.most_recent_history(name)
      RailsAdmin::History.most_recent name
    end

  end

end
