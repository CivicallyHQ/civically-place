import { default as computed, on } from 'ember-addons/ember-computed-decorators';
import { updateAppData } from 'discourse/plugins/civically-app/discourse/lib/app-utilities';
import { cook, cookAsync } from 'discourse/lib/text';
import Category from 'discourse/models/category';
import DiscourseURL from 'discourse/lib/url';

export default Ember.Component.extend({
  classNameBindings: [':place-user-controls', 'showPetition'],
  inputFields: ['city', 'countrycode'],
  showPetition: false,
  searchingPetitions: false,
  placeTitle: '',
  place: Ember.computed.alias('currentUser.place'),
  loadingNewWindow: false,

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

  @on('init')
  setPlaceText() {
    const place = this.get('place');

    if (place) {
      const placeTitle = I18n.t('place.current.title', { placeName: place.name, placeUrl: place.topic_url });
      cookAsync(placeTitle).then((cooked) => this.set('placeTitle', cooked));

      const pointsDescription = I18n.t('place.points.description');
      cookAsync(pointsDescription).then((cooked) => this.set('pointsDescription', cooked));
    }
  },

  @computed('currentUser.place_joined_at')
  updatePlaceAllowed(joinedAt) {
    return joinedAt && moment(joinedAt).diff(moment().format(), 'days') >= Discourse.SiteSettings.place_change_min;
  },

  @computed('currentUser.place_joined_at')
  nextTime(joinedAt) {
    return moment(joinedAt).add(Discourse.SiteSettings.place_change_min, 'days');
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

  @computed('showPetition')
  showNotListedNote(showPetition) {
    return !this.site.mobileView && !showPetition;
  },

  willDestroyElement() {
    this.appEvents.off('place-select:add-place', (f) => this.send('showPetition', f));
  },

  @computed()
  petitionDescription() {
    return cook(I18n.t('place.select.petition.description'));
  },

  @computed()
  petitionNote() {
    return cook(I18n.t('place.select.petition.note'));
  },

  actions: {
    setPlace(selectedId) {
      const placeCategoryId = this.get('currentUser.place_category_id');

      if (!selectedId || selectedId === placeCategoryId) return;

      this.set('loading', true);

      Category.setPlace(selectedId).then((result) => {
        this.set('loading', false);

        if (result.error) {
          return bootbox.alert(result.error);
        }

        const user = this.get('currentUser');
        let userProps = {};
        let category = null;

        if (result.place_category_id) {
          let categoryId = Number(result.place_category_id);

          category = Category.findById(categoryId);

          userProps['place_category_id'] = categoryId;
        }

        if (result.place) {
          userProps['place'] = result.place;
        }

        if (result.place_joined_at) {
          userProps['place_joined_at'] = result.place_joined_at;
        }

        if (result.place_points) {
          userProps['place_points'] = result.place_points;
        }

        user.setProperties(userProps);

        if (result.app_data) {
          let appData = result.app_data;

          Object.keys(appData).forEach(appName => {
            updateAppData(user, appName, appData[appName]);
          });
        }

        if (this.get('routeAfterSet') && category) {
          DiscourseURL.routeTo(category.get('url'));
        }
      });
    },

    addPlace() {
      this.set('loadingNewWindow', true);
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
