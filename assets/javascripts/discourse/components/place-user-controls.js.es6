import { default as computed, on } from 'ember-addons/ember-computed-decorators';
import Place from '../models/place';
import Category from 'discourse/models/category';
import DiscourseURL from 'discourse/lib/url';

export default Ember.Component.extend({
  classNames: ['place-user-controls'],
  inputFields: ['city', 'countrycode'],
  showExtraControls: false,

  @on('init')
  initSelectedId() {
    let selectedId = null;

    const filter = window.location.search;
    if (filter.indexOf('default') > -1) {
      selectedId = filter.split('=')[1];
    }

    const placeCategoryId = this.get('currentUser.place_category_id');
    if (placeCategoryId) {
      selectedId = placeCategoryId;
    }

    this.set('selectedId', selectedId);
  },

  @computed('place.joined_at')
  updatePlaceAllowed(joinedAt) {
    return joinedAt && moment(joinedAt).diff(moment().format(), 'days') >= Discourse.SiteSettings.place_change_min;
  },

  @computed('place', 'updatePlaceAllowed')
  setPlaceAllowed(place, updatePlaceAllowed) {
    return !place || updatePlaceAllowed;
  },

  @computed('selectedId', 'currentUser.place_category_id', 'setPlaceAllowed')
  setDisabled(selectedId, placeCategoryId, setPlaceAllowed) {
    return !selectedId || selectedId === placeCategoryId || !setPlaceAllowed;
  },

  actions: {
    setPlace(selectedId) {
      const placeCategoryId = this.get('currentUser.place_category_id');

      if (!selectedId || selectedId === placeCategoryId) return;

      this.set('loading', true);
      Place.set(selectedId).then((result) => {
        this.set('loading', false);
        if (result.error) {
          return bootbox.alert(result.error);
        }

        Discourse.User.current().set('place_category_id', Number(selectedId));
        if (this.get('routeAfterSet')) {
          DiscourseURL.routeTo(Category.findById(selectedId).get('url'));
        }
      });
    },

    addPlace() {
      window.location.href = '/w/place-petition';
    },

    toggleExtraControls() {
      this.set('showExtraControls', true);
    }
  }
});
