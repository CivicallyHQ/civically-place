export default {
  name: 'place-category-routes',
  initialize(container){
    const site = container.lookup('site:main');
    if (site.mobileView) return;

    let categoryRoutes = [
      'Category',
      'CategoryNone'
    ];

    let parentCategoryRoutes = [
      'ParentCategory',
    ];

    let filters = site.get('filters');
    filters.push('top');
    filters.forEach(filter => {
      const filterCapitalized = filter.capitalize();
      categoryRoutes.push(...[
        `${filterCapitalized}Category`,
        `${filterCapitalized}CategoryNone`
      ]);
      parentCategoryRoutes.push(...[
        `${filterCapitalized}ParentCategory`,
      ]);
    });

    site.get('periods').forEach(period => {
      const periodCapitalized = period.capitalize();
      categoryRoutes.push(...[
        `Top${periodCapitalized}Category`,
        `Top${periodCapitalized}CategoryNone`
      ]);
      parentCategoryRoutes.push(...[
        `Top${periodCapitalized}ParentCategory`,
      ]);
    });

    parentCategoryRoutes.forEach(function(route){
      if (route = container.lookup(`route:discovery.${route}`)) {
        route.reopen({
          afterModel() {
            // do nothing for now;
            return this._super(...arguments);
          }
        });
      }
    });
  }
};
