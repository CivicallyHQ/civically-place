import ComboBoxComponent from "select-kit/components/combo-box";
import { observes } from 'ember-addons/ember-computed-decorators';

export default ComboBoxComponent.extend({
  init() {
    this._super();
    this.appEvents.on('place-select:add-place', () => this.didSelect());
  },

  willDestroyElement() {
    this.appEvents.off('place-select:add-place', () => this.didSelect());
  },

  @observes('filter', 'shouldDisplayNoContentRow')
  setRowComponentOptions() {
    const filter = this.get('filter');
    const noContent = this.get('shouldDisplayNoContentRow');
    this.get("rowComponentOptions").setProperties({
      filter,
      noContent
    });
  }
});
