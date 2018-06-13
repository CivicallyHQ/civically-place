import { ajax } from 'discourse/lib/ajax';
import { resolvePlaceSet } from '../lib/place-utilities';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: 'town-add container',
  addingTown: false,
  locationSearchError: null,
  geoAttrs: ['name', 'district', 'state', 'country'],
  addContext: 'place_add',

  @computed('geoLocation', 'addingTown')
  addTownDisabled(geoLocation, addingTown) {
    return !geoLocation || addingTown;
  },

  actions: {
    addTown() {
      const geoLocation = this.get('geoLocation');
      if (!geoLocation) return;

      this.set('addingTown', true);

      ajax('/place/add', {
        type: 'PUT',
        data: {
          geo_location: geoLocation
        }
      }).then((result) => {
        if (resolvePlaceSet(result) && this.get('routeAfterSet') && result.route_to) {
          this.set('loadingNewWindow', true);
          window.location = result.route_to;
        }
      }).catch(popupAjaxError).finally(() => {
        this.setProperties({
          loading: false,
          addingTown: false
        });
      });
    },

    locationSearchError(error) {
      this.set('locationSearchError', error);
    }
  }
})
