UserHistory.actions[:place] = 1001

User.class_eval do
  def place_category_id
    if self.custom_fields['place_category_id']
      self.custom_fields['place_category_id']
    else
      nil
    end
  end

  def place_score
    if self.custom_fields['place_score']
      self.custom_fields['place_score'].to_i
    else
      0
    end
  end

  def self.update_place_category_id(user, category_id, force = nil)
    place = CivicallyPlace::Place.new(category_id, user)

    if !place
      return { error: I18n.t('user.errors.place_not_found') }
    end

    if place.member
      return { error: I18n.t('user.errors.place_not_changed') }
    end

    if user.place_category_id
      user_place = CivicallyPlace::Place.new(user.place_category_id, user)
      change_min = SiteSetting.place_change_min.to_i

      if !force && (Time.now.to_date - user_place.joined_at).round < change_min
        next_time = (user_place.joined_at + change_min).strftime("%B %d")
        past_time = user_place.joined_at.strftime("%B %d")

        return {
          error: I18n.t('user.errors.place_set_limit',
            past_time: past_time,
            place: user_place.category.name,
            next_time: next_time,
            change_min: change_min),
          status: 403
        }
      end

      CivicallyPlace::PlaceManager.update_user_count(user_place.category.id, -1)
    else
      CivicallyChecklist::Checklist.update_item(user, 'set_place', checked: true)
      CivicallyChecklist::Checklist.update_item(user, 'set_place', active: false)
      CivicallyChecklist::Checklist.update_item(user, 'pass_petition', checked: true)
      CivicallyChecklist::Checklist.update_item(user, 'pass_petition', active: false)
    end

    CivicallyPlace::PlaceManager.update_user_count(category_id, 1)

    if place.has_moderator_election
      CivicallyPlace::User.add_elect_moderator_to_checklist(user, place)
    end

    UserHistory.create(
      action: UserHistory.actions[:place],
      acting_user_id: user.id,
      category_id: category_id
    )

    user.custom_fields['place_category_id'] = category_id
    user.save_custom_fields(true)

    { place_category_id: user.place_category_id }
  end
end

class CivicallyPlace::User
  def self.add_pass_petition_to_checklist(user)
    petition_checklist_item = {
      id: "pass_petition",
      checked: false,
      checkable: false,
      active: true,
      title: I18n.t('checklist.place_setup.pass_petition.title'),
      detail: I18n.t('checklist.place_setup.pass_petition.detail')
    }

    CivicallyChecklist::Checklist.add_item(user, petition_checklist_item, 1)
    CivicallyChecklist::Checklist.update_item(user, 'set_place', active: false)
  end

  def self.add_elect_moderator_to_checklist(user, place)
    CivicallyChecklist::Checklist.add_item(user,
      id: "elect_moderator",
      checked: false,
      checkable: false,
      active: true,
      title: I18n.t('checklist.place_setup.elect_moderator.title'),
      detail: I18n.t('checklist.place_setup.elect_moderator.detail', mod_url: place.moderator_election_url)
    )
  end
end

# If a user is invited to a petition topic it should be set as their place topic id
module InvitesControllerCivicallyUser
  private def post_process_invite(user)
    super(user)
    if user
      invite = Invite.find_by(invite_key: params[:id])
      topic = invite.topics.first
      if topic && topic.petition && topic.petition_status === 'open'
        user.custom_fields['place_topic_id'] = topic.id
        user.save_custom_fields(true)
      end
    end
  end
end

require_dependency 'invites_controller'
class ::InvitesController
  prepend InvitesControllerCivicallyUser
end
