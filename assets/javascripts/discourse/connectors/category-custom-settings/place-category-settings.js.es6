export default {
  setupComponent(attrs, component) {
    component.set('placeTypes', [
      'international',
      'country',
      'town',
      'neighbourhood'
    ]);

    if (Discourse.User.currentProp('admin')) {
      component.set('placeLocation', JSON.stringify(attrs.category.custom_fields.location));

      component.addObserver('placeLocation', function() {
        if (this._state === 'destroying') return;

        Ember.run.debounce(this, () => {
          try {
            let placeLocation = component.get('placeLocation');
            JSON.parse(placeLocation);
            attrs.category.custom_fields.location = placeLocation;
            component.set('jsonError', null);
            console.log(attrs.category.custom_fields);
          } catch (e) {
            component.set('jsonError', e);
          }
        }, 100);
      });
    }
  }
}
