require_dependency 'topic'
class ::Topic
  def region_ids
    [*self.custom_fields['region_id']]
  end
end

TopicList.preloaded_custom_fields << "region_id" if TopicList.respond_to? :preloaded_custom_fields

PostRevisor.track_topic_field(:region_ids) do |tc, region_ids|
  TopicCustomField.where(topic_id: tc.topic.id, name: 'region_id').delete_all

  save_regions = []
  highest_place = nil

  region_ids.each do |region_id|
    if region = CivicallyPlace::Region.find(region_id)
      place = CivicallyPlace::Place.find(region[:category_id])

      if !highest_place || CivicallyPlace::Place.higher_place(place, highest_place)
        highest_place = place
        tc.topic.custom_fields['location'] = region
      end

      save_regions.push(region_id)
    end
  end

  if save_regions.length
    save_regions = save_regions[0] if save_regions.length === 1
    tc.topic.custom_fields['region_id'] = save_regions
  end
end

PostRevisor.track_topic_field(:region_ids_empty_array) do |tc, region_ids_empty_array|
  if region_ids_empty_array
    TopicCustomField.where(topic_id: tc.topic.id, name: 'region_id').delete_all
  end
end

module PlaceTopicQueryExtension
  def default_results(options = {})
    options.reverse_merge!(@options)
    category_id = get_category_id(options[:category])
    @options[:category_id] = category_id

    if category_id && place = CivicallyPlace::Place.find_by(id: category_id)
      options.reverse_merge!(per_page: per_page_setting)

      # Whether to return visible topics
      options[:visible] = true if @user.nil? || @user.regular?
      options[:visible] = false if @user && @user.id == options[:filtered_to_user]

      # Start with a list of all topics
      result = Topic.unscoped

      if @user
        result = result.joins("LEFT OUTER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{@user.id.to_i})")
          .references('tu')
      end

      place_category_ids = [category_id]

      if place.is_town
        place_category_ids += [place.country.id]
      elsif place.is_neighbourhood
        place_category_ids += [place.country.id, place.town.id]
      end

      region_ids = []

      if place.region_ids.any?
        region_ids += place.region_ids
      end

      if place.region_membership_ids.any?
        region_ids += place.region_membership_ids
      end

      if place.region_ids.any?
        result = result.where("topics.id IN (
          SELECT id FROM topics WHERE topics.category_id in (#{place_category_ids.join(",")})
          UNION
          SELECT topic_id FROM topic_custom_fields
          WHERE name = 'region_id' AND value IN (?)
        )", region_ids)
      else
        result = result.where("topics.category_id in (?)", place_category_ids)
      end

      result = result.references(:categories)

      if !@options[:order]
        # category default sort order
        sort_order, sort_ascending = Category.where(id: category_id).pluck(:sort_order, :sort_ascending).first
        if sort_order
          options[:order] = sort_order
          options[:ascending] = !!sort_ascending ? 'true' : 'false'
        end
      end

      # ALL TAGS: something like this?
      # Topic.joins(:tags).where('tags.name in (?)', @options[:tags]).group('topic_id').having('count(*)=?', @options[:tags].size).select('topic_id')

      if SiteSetting.tagging_enabled
        result = result.preload(:tags)

        if @options[:tags] && @options[:tags].size > 0

          if @options[:match_all_tags]
            # ALL of the given tags:
            tags_count = @options[:tags].length
            @options[:tags] = Tag.where(name: @options[:tags]).pluck(:id) unless @options[:tags][0].is_a?(Integer)

            if tags_count == @options[:tags].length
              @options[:tags].each_with_index do |tag, index|
                sql_alias = ['t', index].join
                result = result.joins("INNER JOIN topic_tags #{sql_alias} ON #{sql_alias}.topic_id = topics.id AND #{sql_alias}.tag_id = #{tag}")
              end
            else
              result = result.none # don't return any results unless all tags exist in the database
            end
          else
            # ANY of the given tags:
            result = result.joins(:tags)
            if @options[:tags][0].is_a?(Integer)
              result = result.where("tags.id in (?)", @options[:tags])
            else
              result = result.where("tags.name in (?)", @options[:tags])
            end
          end
        elsif @options[:no_tags]
          # the following will do: ("topics"."id" NOT IN (SELECT DISTINCT "topic_tags"."topic_id" FROM "topic_tags"))
          result = result.where.not(id: TopicTag.distinct.pluck(:topic_id))
        end
      end

      result = apply_ordering(result, options)
      result = result.listable_topics.includes(:category)
      result = apply_shared_drafts(result, category_id, options)

      if options[:exclude_category_ids] && options[:exclude_category_ids].is_a?(Array) && options[:exclude_category_ids].size > 0
        result = result.where("categories.id NOT IN (?)", options[:exclude_category_ids].map(&:to_i)).references(:categories)
      end

      # Don't include the category topics if excluded
      if options[:no_definitions]
        result = result.where('COALESCE(categories.topic_id, 0) <> topics.id')
      end

      result = result.limit(options[:per_page]) unless options[:limit] == false
      result = result.visible if options[:visible]
      result = result.where.not(topics: { id: options[:except_topic_ids] }).references(:topics) if options[:except_topic_ids]

      if options[:page]
        offset = options[:page].to_i * options[:per_page]
        result = result.offset(offset) if offset > 0
      end

      if options[:topic_ids]
        result = result.where('topics.id in (?)', options[:topic_ids]).references(:topics)
      end

      if search = options[:search]
        result = result.where("topics.id in (select pp.topic_id from post_search_data pd join posts pp on pp.id = pd.post_id where pd.search_data @@ #{Search.ts_query(term: search.to_s)})")
      end

      # NOTE protect against SYM attack can be removed with Ruby 2.2
      #
      state = options[:state]
      if @user && state &&
          TopicUser.notification_levels.keys.map(&:to_s).include?(state)
        level = TopicUser.notification_levels[state.to_sym]
        result = result.where('topics.id IN (
                                  SELECT topic_id
                                  FROM topic_users
                                  WHERE user_id = ? AND
                                        notification_level = ?)', @user.id, level)
      end

      require_deleted_clause = true

      if before = options[:before]
        if (before = before.to_i) > 0
          result = result.where('topics.created_at < ?', before.to_i.days.ago)
        end
      end

      if bumped_before = options[:bumped_before]
        if (bumped_before = bumped_before.to_i) > 0
          result = result.where('topics.bumped_at < ?', bumped_before.to_i.days.ago)
        end
      end

      if status = options[:status]
        case status
        when 'open'
          result = result.where('NOT topics.closed AND NOT topics.archived')
        when 'closed'
          result = result.where('topics.closed')
        when 'archived'
          result = result.where('topics.archived')
        when 'listed'
          result = result.where('topics.visible')
        when 'unlisted'
          result = result.where('NOT topics.visible')
        when 'deleted'
          guardian = @guardian
          if guardian.is_staff?
            result = result.where('topics.deleted_at IS NOT NULL')
            require_deleted_clause = false
          end
        end
      end

      if (filter = options[:filter]) && @user
        action =
          if filter == "bookmarked"
            PostActionType.types[:bookmark]
          elsif filter == "liked"
            PostActionType.types[:like]
          end
        if action
          result = result.where('topics.id IN (SELECT pp.topic_id
                                FROM post_actions pa
                                JOIN posts pp ON pp.id = pa.post_id
                                WHERE pa.user_id = :user_id AND
                                      pa.post_action_type_id = :action AND
                                      pa.deleted_at IS NULL
                             )', user_id: @user.id,
                                 action: action
                             )
        end
      end

      result = result.where('topics.deleted_at IS NULL') if require_deleted_clause
      result = result.where('topics.posts_count <= ?', options[:max_posts]) if options[:max_posts].present?
      result = result.where('topics.posts_count >= ?', options[:min_posts]) if options[:min_posts].present?

      result = TopicQuery.apply_custom_filters(result, self)

      @guardian.filter_allowed_categories(result)
    else
      super(options = {})
    end
  end
end

require_dependency 'topic_query'
class ::TopicQuery
  prepend PlaceTopicQueryExtension
end
