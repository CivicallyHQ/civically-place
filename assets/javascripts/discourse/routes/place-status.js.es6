import Place from '../models/place';

export default Ember.Route.extend({
  model(params) {
    return Place.create({ category_id: params.id });
  }
});
