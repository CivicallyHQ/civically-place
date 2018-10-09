import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  geoAttrs: ['name', 'district', 'state', 'country'],
  addContext: 'region_add',

  @computed('regionName')
  addRegionDisabled(regionName) {
    return !regionName || regionName.length < 2;
  },

  @computed('regionName', 'regionLocation')
  region(name, location) {
    return {
      name,
      geo_location: location
    }
  },

  actions: {
    locationSearchError(error) {
      this.set('locationSearchError', error);
    },

    addRegion() {
      this.get('model.addRegion')(this.get('region'))
    }
  }
})
