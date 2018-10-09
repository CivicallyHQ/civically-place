import { getRegions } from '../../lib/place-utilities';

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
          } catch (e) {
            component.set('jsonError', e);
          }
        }, 100);
      });
    }

    let isTown = attrs.category.place_type === 'town';

    const regions = getRegions(attrs.category);
    component.setProperties({
      regions,
      isTown
    });

    if (isTown) {
      let regionMembershipsRaw = attrs.category.custom_fields.region_membership_id;
      let regionMemberships = Array.isArray(regionMembershipsRaw) ? regionMembershipsRaw : [regionMembershipsRaw];
      component.set('regionMemberships', regionMemberships);

      component.addObserver('regionMemberships.[]', function() {
        if (this._state === 'destroying') return;
        attrs.category.custom_fields.region_membership_id = component.get('regionMemberships');
      });
    }
  }
};
