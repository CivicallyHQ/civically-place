import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  isTown: Ember.computed.equal('category.place_type', 'town'),
  isNeighbourhood: Ember.computed.equal('category.place_type', 'neighbourhood'),

  @computed('currentUser.town.user_count', 'currentUser.town.user_count_min')
  hasMinUsers(userCount, userCountMin) {
    return userCount >= userCountMin;
  },

  @computed('currentUser.neighbourhood_petition_id', 'currentUser.neighbourhood_category_id')
  showNeighourhoodPrompts(petitionId, categoryId) {
    return !petitionId && !categoryId;
  },

  @computed('currentUser.town', 'currentUser.town.user_count')
  lowUsers(town, userCount) {
    if (town) {
      let key = userCount > 1 ? 'place.user_count.low_many' : 'place.user_count.low_one';
      return I18n.t(key, {
        placeName: town.name,
        userCount: town.user_count,
        userCountMin: town.user_count_min
      });
    }
  }
});
