import { default as computed, on, observes } from 'ember-addons/ember-computed-decorators';
import { placeTypes } from '../lib/place-utilities';
import { cookAsync } from 'discourse/lib/text';
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import Category from 'discourse/models/category';

export default Ember.Component.extend({
  classNameBindings: [':place-user-controls', 'showAddTown'],
  showAddTown: false,
  showHome: Ember.computed.alias('currentUser.town'),

  @on('init')
  initSelectedId() {
    let selectedId = null;

    const filter = window.location.search;
    if (filter.indexOf('default') > -1) {
      selectedId = filter.split('=')[1];
    }

    const townCategoryId = this.get('currentUser.town_category_id');
    if (townCategoryId) {
      selectedId = townCategoryId;
    }

    this.set('selectedId', selectedId);
    this.appEvents.on('town-set:add-town', (f) => {
      this.send('toggleShowAddTown', f);
    });
  },

  @on('init')
  setText() {
    const town = this.get('currentUser.town');

    if (town) {
      const rawTown = I18n.t('place.town.current', {
        townName: town.name,
        townUrl: town.topic_url
      });

      cookAsync(rawTown).then((cooked) => this.set('currentTown', cooked));

      const neighbourhood = this.get('currentUser.neighbourhood');

      if (neighbourhood) {
        const rawNeighbourhood = I18n.t('place.neighbourhood.current', {
          neighbourhoodName: neighbourhood.name,
          neighbourhoodUrl: neighbourhood.topic_url
        });

        cookAsync(rawNeighbourhood).then((cooked) => this.set('currentNeighbourhood', cooked));
      }
    }
  },

  @computed('currentUser.town', 'currentUser.town_joined_at')
  canSetTown(town, joinedAt) {
    return !town ||
           (joinedAt &&
            moment(joinedAt).diff(moment().format(), 'days') >= Discourse.SiteSettings.place_town_change_min);
  },

  @computed('currentUser.town_joined_at')
  townNextTime(joinedAt) {
    return moment(joinedAt).add(Discourse.SiteSettings.place_town_change_min, 'days');
  },

  @computed('currentUser.town', 'currentUser.neighbourhood', 'currentUser.neighbourhood_joined_at')
  canSetNeighbourhood(town, neighbourhood, joinedAt) {
    return town &&
           (joinedAt &&
            moment(joinedAt).diff(moment().format(), 'days') >= Discourse.SiteSettings.place_neighbourhood_change_min);
  },

  @computed('currentUser.neighbourhood_joined_at')
  neighbourhoodNextTime(joinedAt) {
    return moment(joinedAt).add(Discourse.SiteSettings.place_neighbourhood_change_min, 'days');
  },

  @computed('canSetTown', 'showAddTown')
  showAddTownBtn(canSetTown, showAddTown) {
    return !this.site.mobileView && canSetTown && !showAddTown;
  },

  @computed('currentUser.town')
  country(town) {
    return Category.findById(town.parent_category_id);
  },

  @on('init')
  setCurrentHome() {
    this.set('currentHome', this.get('currentUser.place_home'));
  },

  @on('init')
  @observes('currentUser.place_home')
  setHomeTitle() {
    const showHome = this.get('showHome');
    if (showHome) {
      const home = this.get('home');
      const rawHome = I18n.t('place.home.current', {
        homeName: home.name,
        homeUrl: home.topic_url
      })

      cookAsync(rawHome).then((cooked) => {
        this.set('homeTitle', cooked);
      });
    }
  },

  @computed('currentUser.place_home')
  home(home) {
    if (home === 'country') {
      return this.get('country');
    } else {
      return this.get(`currentUser.${home}`);
    }
  },

  @computed('currentUser.town', 'currentUser.neighbourhood')
  homes(town, neighbourhood) {
    if (!town) return [];

    let placeTypes = [
      'country',
      'town'
    ]

    if (neighbourhood) placeTypes.push('neighbourhood');

    return placeTypes.map((type) => {
      let params = {};

      if (type === 'country') {
        params[`${type}Name`] = this.get('country.name');
      } else {
        params[`${type}Name`] = type === 'town' ? town.name : neighbourhood.name;
      }

      return {
        id: type,
        name: I18n.t(`place.home.${type}`, params)
      }
    });
  },

  @computed('settingHome')
  setHomeDisabled(settingHome) {
    return settingHome;
  },

  willDestroyElement() {
    this.appEvents.off('place-select:add-town', (f) => this.send('toggleShowAddTown', f));
  },

  actions: {
    toggleShowAddTown(filter) {
      this.set('showAddTown', true);

      Ember.run.scheduleOnce('afterRender', () => {
        const addOffset = $(".town-add").offset().top;
        const headerHeight = $('.d-header').height();
        const offset = addOffset - headerHeight;

        $('html, body').animate({
          scrollTop: offset
        }, 500, () => {
          $('.town-add input.location-selector').focus();
        });
      });
    },

    setHome() {
      this.set('settingHome', true);

      ajax('/place/user/set-home', {
        type: 'PUT',
        data: {
          place_home: this.get('currentHome')
        }
      }).then((result) => {
        if (result.success) {
          Discourse.User.currentProp('place_home', result.place_home);
        } else {
          this.set('currentHome', this.get('currentUser.place_home'));
        }
      }).catch(popupAjaxError).finally(() => this.set('settingHome', false));
    }
  }
});
