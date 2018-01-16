export default function() {
  this.route('place', {path: '/place'}, function() {
    this.route('set', {path: '/set'});
    this.route('status', {path: 'status/:id'});
  });
}
