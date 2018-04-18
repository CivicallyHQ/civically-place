import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: ['place-select'],

  @computed('currentUser.place_category_id')
  places(userPlaceCategoryId) {
    return this.site.get('categoriesList')
      .filter(c => c.is_place && c.place_type !== 'country');
  },

  actions: {
    setPlace() {
      this.sendAction('setPlace', this.get('selectedId'));
    }
  }
});
