import { observes, on } from 'ember-addons/ember-computed-decorators';
import Place from '../models/place';

export default Ember.Component.extend({
  classNames: ['place-select'],

  @on('init')
  @observes('user.place_category_id')
  setup() {
    const user = this.get('user');
    if (!user) {
      this.set('user', this.get('currentUser'));
    }

    Place.list({ can_join: true }).then((result) => {
      if (this._state === 'destroying') return;
      const placeCategoryId = this.get('user.place_category_id');
      const places = result.map((p) => {
        if (p.id === placeCategoryId) {
          p.name += ` ${I18n.t('user.current_place_marker')}`;
        }
        return p;
      });
      this.set('places', places);
    });
  },

  @on('init')
  @observes('selectedId')
  getSelectedPlace() {
    const selectedPlace = this.get('selectedPlace');
    const selectedId = this.get('selectedId');
    if (!selectedId || (selectedPlace && selectedPlace.id === selectedId)) return;

    this.set('loadingSelectedPlace', true);
    Place.create({ category_id: selectedId }).then((result) => {
      if (this._state === 'destroying') return;

      this.setProperties({
        'loadingSelectedPlace': false,
        'selectedPlace': result
      });
    });
  },

  actions: {
    setPlace() {
      this.sendAction('setPlace', this.get('selectedId'));
    },

    addPlace(filter) {
      this.sendAction('addPlace', filter);
    }
  }
});
