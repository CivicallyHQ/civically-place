import { ajax } from 'discourse/lib/ajax';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import { placeLabel } from '../lib/place-utilities';
import showModal from "discourse/lib/show-modal";

export default Ember.Controller.extend({
  regions: Ember.A(),

  @computed
  places() {
    return this.site.get('categoriesList').filter(c => c.is_place);
  },

  @computed('categoryId')
  placeLabel(categoryId) {
    return placeLabel(categoryId);
  },

  @computed('hasRegions', 'loading')
  showRegions(hasRegions, loading) {
    return hasRegions && !loading;
  },

  @computed('regions')
  hasRegions(regions) {
    return regions && regions[0];
  },

  @observes('categoryId')
  getRegions() {
    const categoryId = this.get('categoryId');
    if (categoryId) {
      ajax(`/place/regions/${categoryId}`).then((result) => {
        this.set('regions', Ember.A(result));
      });
    }
  },

  addRegion(region) {
    this.set('loading', true);
    ajax(`/place/regions/${this.get('categoryId')}`, {
      type: "PUT",
      data: { region }
    }).then((result) => {
      if (result.region) {
        this.get('regions').addObject(result.region);
      }
    }).finally(() => this.set('loading', false));
  },

  removeRegion(regionId) {
    this.set('loading', true);
    ajax(`/place/regions/${this.get('categoryId')}`, {
      type: "DELETE",
      data: {
        region_id: regionId
      }
    }).then((result) => {
      if (result.region_id) {
        let regions = this.get('regions');
        regions.removeObject(regions.findBy('id', result.region_id));
      }
    }).finally(() => this.set('loading', false));
  },

  actions: {
    changeRegion() {
      this.getRegions();
    },

    removeRegion(regionId) {
      this.removeRegion(regionId);
      this.set('loading', true);
    },

    openAddRegion() {
      showModal('add-region', {
        model: {
          placeLabel: this.get('placeLabel'),
          addRegion: (region) => {
            this.addRegion(region);
          }
        }
      });
    }
  }
});
