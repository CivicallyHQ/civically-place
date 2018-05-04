import ComboBoxComponent from "select-kit/components/combo-box";
import { observes } from 'ember-addons/ember-computed-decorators';

export default ComboBoxComponent.extend({
  // Allows noneRow to display when select-kit has no contents
  hasSelection: true,
  none: 'place.select.placeholder',
  classNames: "place-select-box",
  includeCountries: false,

  init() {
    this._super();
    this.appEvents.on('place-select:add-place', () => this.didSelect());
  },

  willDestroyElement() {
    this.appEvents.off('place-select:add-place', () => this.didSelect());
  },

  computeContent() {
    let places = this.site.get('categoriesList').filter(c => c.is_place);

    const includeCountries = this.get('includeCountries');
    if (!includeCountries) {
      places = places.filter(c => c.place_type !== 'country')
    }

    return places;
  },

  @observes('filter', 'noContentRow')
  setRowComponentOptions() {
    const filter = this.get('filter');
    const noContent = Boolean(this.get('noContentRow'));
    this.get("rowComponentOptions").setProperties({
      filter,
      noContent
    });
  }
});
