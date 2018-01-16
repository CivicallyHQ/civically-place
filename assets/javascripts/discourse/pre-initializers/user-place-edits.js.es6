import { withPluginApi } from 'discourse/lib/plugin-api';
import { observes, on } from 'ember-addons/ember-computed-decorators';
import Place from '../models/place';

export default {
  name: 'user-place-edits',
  initialize() {
    withPluginApi('0.8.12', api => {
      api.modifyClass('controller:application', {
        @on('init')
        @observes('currentUser.place_category_id')
        setupUserPlace() {
          const placeCategoryId = this.get('currentUser.place_category_id');
          const userPlaceCategoryId = this.get('userPlace.category.id');
          if (placeCategoryId && (placeCategoryId !== userPlaceCategoryId)) {
            Place.create({ category_id: placeCategoryId }).then((result) => {
              this.set('userPlace', result);
            });
          }
        }
      });
    });
  }
};
