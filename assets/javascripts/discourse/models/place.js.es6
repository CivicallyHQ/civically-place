import { default as computed } from 'ember-addons/ember-computed-decorators';
import { ajax } from 'discourse/lib/ajax';

const Place = Discourse.Model.extend({
  isFounding: Ember.computed.equal('status', 'founding'),
  hasGeojson: Ember.computed.notEmpty('geojson'),

  @computed('user_count')
  userCountDiff(userCount) {
    const userCountMin = this.get('user_count_min');
    return Math.max(userCountMin - userCount, 0);
  },

  @computed('userCountDiff')
  reachedUserCount(userCountDiff) {
    return userCountDiff === 0;
  },

  @computed('joined_at')
  nextTime(joinedAt) {
    return moment(joinedAt).add(Discourse.SiteSettings.place_change_min, 'days');
  }
});

Place.reopenClass({
  list(opts) {
    return ajax('/place/list', { data: { opts }}).then((result) => {
      return result.places;
    });
  },

  create() {
    const place = this._super.apply(this, arguments);
    const categoryId = place.get('category_id');

    return ajax(`/place/get/${categoryId}`).then((result) => {
      let props = result.place_user || result.place;
      place.setProperties(props);
      return place;
    });
  },

  set(category_id, user_id = null) {
    let data = { category_id };
    if (user_id) data['user_id'] = user_id;
    return ajax('/place/set', { type: 'POST', data });
  }
});

export default Place;
