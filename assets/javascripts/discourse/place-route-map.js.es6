export default function() {
  this.route('place', {path: '/place'}, function() {
    this.route('set', {path: '/set'});
    this.route('regions', {path: '/regions/:category_id'});
  });
}
