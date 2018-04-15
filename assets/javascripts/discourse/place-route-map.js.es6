export default function() {
  this.route('place', {path: '/place'}, function() {
    this.route('set', {path: '/set'});
  });
}
