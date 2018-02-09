import { default as computed, on } from 'ember-addons/ember-computed-decorators';
import Place from '../models/place';
import Category from 'discourse/models/category';
import DiscourseURL from 'discourse/lib/url';

export default Ember.Component.extend({
  classNameBindings: [':place-user-controls', 'showPetition'],
  inputFields: ['city', 'countrycode'],
  showPetition: false,
  searchingPetitions: false,
  placeTitle: '',

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
    this.appEvents.on('place-select:add-place', (f) => this.send('showPetition', f));
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

  @computed('placeTitle')
  noPetitions(title) {
    if (title) {
      return I18n.t("place.select.petition.search.none_title", { title });
    } else {
      return I18n.t("place.select.petition.search.none");
    }
  },

  willDestroyElement() {
    this.appEvents.off('place-select:add-place', (f) => this.send('showPetition', f));
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

    showPetition(filter) {
      if (filter) this.set('placeTitle', filter);
      this.set('showPetition', true);

      Ember.run.scheduleOnce('afterRender', () => {
        const petitionOffset = $(".place-petition").offset().top;
        const headerHeight = $('.d-header').height();
        const offset = petitionOffset - headerHeight + 10;
        $('html, body').animate({
          scrollTop: offset
        }, 500);
      });
    }
  }
});
