import 'dart:convert';
import 'dart:io';
import 'Client.dart';
import 'package:dotenv/dotenv.dart' show load, env;

void main() async {
  await load();
  // get the API key and client ID
  var key = env['KEY'];
  var id = env['CLIENT_ID'];
  Endpoint end = Endpoint(id, key);

  var file = await end.categories_();

  var data = file['response']['categories'];
  var categories = cleanCategories(data, null, filtered: {});
  print(categories);

  var cat = jsonEncode(categories);
  var filename = 'categories.json';
  new File(filename).writeAsString(cat);
}

dynamic cleanCategories(List data, String parent,
    {bool isChild = false, Map filtered}) {
  
  num totalCategories = 0;
  // check to see if you're working with a child or not
  if (isChild == true) {
    // create a child list
    List children = [];
    // loop through each child
    for (var child in data) {
      // get the usable data
      var id = child['id'];
      String name = child['name'].toLowerCase();
      var hasChildren = child['categories'].length > 0 ? true : false;
      filtered[name] = {};
      filtered[name]['id'] = id;
      filtered[name]['has_children'] = hasChildren;
      filtered[name]['is_child'] = isChild;

      // add the parents of the category
      var parents = [];
      // add all previous parents
      filtered[parent]['parents'].forEach((p) => parents.add(p));
      //add the current parent
      parents.add(parent);
      // add the parents list to the children
      filtered[name]['parents'] = parents;


      // if the current child has children
      // repeat the process for the children
      if (hasChildren) {
        filtered[name]['children'] =
            getAllChildren(child['categories'], children: []);
      }
    }

    // return the list of children for the category
    return children;

  } else if (isChild == false) {
    for (var category in data) {
      totalCategories++;
      // get the usable data
      var id = category['id'];
      var name = category['name'].toLowerCase();
      var hasChildren = category['categories'].length > 0 ? true : false;

      // add the root to filtered
      filtered[name] = {};
      // at the root create a new dict and add the specified fields
      filtered[name]['id'] = id;
      filtered[name]['has_children'] = hasChildren;
      filtered[name]['is_child'] = isChild;

      // add the parents of the category
      filtered[name]['parents'] = [];

      // if the root has children call the function again but using the children
      if (hasChildren) {
        filtered[name]['children'] = cleanCategories(
            category['categories'], name,
            isChild: true, filtered: filtered);
      }

    }
  }

  // once the loop is complete return the categories
  filtered['categories'] = totalCategories;
  filtered['total_categories'] = filtered.length;

  return filtered;
}

List getAllChildren(List data, {List children}) {
  for (var child in data) {
    var name = child['name'].toLowerCase();
    var hasChildren = child['categories'].length > 0 ? true : false;
    children.add({name:child['id']});

    if (hasChildren) {
      getAllChildren(child['categories'], children: children);
    }
  }

  return children;
}

