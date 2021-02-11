// import 'package:foursquare/foursquare.dart';
import 'package:dotenv/dotenv.dart' show load, env;
import 'package:google_maps_webservice/geocoding.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart' as requests;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  await load();
  var x = 'Mall of america';

  // get the API key and client ID
  var key = env['KEY'];
  var id = env['CLIENT_ID'];

  // get the endpoint url
  var searchURL = "https://api.foursquare.com/v2/venues/search";

  // set the desired parameters
  var coordinates = '44.953065,-93.277578';
  var moa = {'lat': 44.854865, 'lng': -93.242215};

  var end = Endpoint(id, key);
  var cat = await end.getCategoryId('fast food');
  print(cat);
}

class Spot extends Endpoint {
  // connect the object to the apis
  final places = GoogleMapsPlaces(apiKey: env['Google_Key']);
  final geocoding = GoogleMapsGeocoding(apiKey: env['Google_Key']);

  // saves all of the places a user searches for
  final recentPlaces = [];

  final String id;
  final String key;
  final Map initialLocation;

  //constructors
  Spot(this.initialLocation, this.id, this.key) : super(id, key);

  // this function takes in a string query for a real place and returns the coordinates
  Future<Map> placeToCoordinates(String place) async {
    // get the response from the api

    Location coordinates = await places
        .searchByText(place)
        .then((value) => value.results[0].geometry.location);

    // add to the list of recently seen places
    recentPlaces.add(place);

    var lat = coordinates.lat;
    var lng = coordinates.lng;

    Map location = {'lat': lat, 'lng': lng};

    // return the coordinates
    // print("Coordinates ${location}");
    return location;
  }

  Future<String> coordinatesToPlace(Map coordinates) {
    // convert the coordinates into a geometry object
    Future<PlacesSearchResponse> p =
        places.searchByText('${coordinates["lat"]},${coordinates["lng"]}');

    var address = p.then((value) => value.results[0].formattedAddress);
    return address;
  }
}

// class for handling endpoint data collection
class Endpoint {
  // credintials
  String client_id;
  String key;
  // holds the default parameters needed for every query
  Map<String, dynamic> baseParams;

  // the base URL for all requests
  final String baseURL = "api.foursquare.com";

  // Holds available venue categories
  Future<Map> get categories async {
    var categories = await new File('categories.json').readAsString();
    Map c = jsonDecode(categories);
    return c;
  }

  String get date {
    final now = DateTime.now();
    final formatter = new DateFormat('yyyyMMdd');
    final dateCode = formatter.format(now);
    return dateCode;
  }

  Endpoint(this.client_id, this.key) {
    baseParams = {'client_id': client_id, 'client_secret': key, 'v': date};
  }

  String _milesToMeters(num value) => (value * 1609.34).toString();

  // ignore: unused_element
  String _metersToMiles(num value) => (value / 1609.34).toString();

  Future<Map> search(dynamic coordinates,
      {int radius, String query, int limit, bool verbose = false}) async {
    // param options
    // coordinates -> latitude and longitude as a string
    // near -> A string naming a place in the world.
    // radius (default: 5 miles) -> Limit results to venues within this many meters of the specified location
    // query -> A search term to be applied against venue names.
    // limit (default: 25) -> Number of results to return, up to 50.

    final String _searchEndpoint = "/v2/venues/search";

    // set the parameters for the request from the base parameters
    var searchParams = baseParams;
    searchParams['ll'] = _convertCoordinates(coordinates);
    searchParams['radius'] =
        radius == null ? _milesToMeters(5) : radius.toString();
    searchParams['query'] = query;
    searchParams['limit'] = limit == null ? '25' : limit.toString();

    // generate the url
    var url = Uri.https(baseURL, _searchEndpoint, searchParams);
    if (verbose) {
      print("Endpoint: Search\nFull URL: $url \n${searchParams}\n");
    }
    // send the request and return the body response
    var response = await requests.get(url);
    var body = json.decode(response.body);
    return body;
  }

  Future<Map> recommend(dynamic coordinates,
      {String section,
      num radius,
      String query,
      int limit,
      bool verbose = false}) async {
    // param options
    // coordinates -> latitude and longitude as a string

    // section -> One of food, drinks, coffee, shops, arts, outdoors, sights, trending,
    //    nextVenues (venues frequently visited after a given venue), or topPicks
    //    (a mix of recommendations generated without a query from the user).
    //    Choosing one of these limits results to venues with the specified category or property.

    // radius -> Limit results to venues within this many meters of the specified location
    // query -> A search term to be applied against venue names.
    // limit -> Number of results to return, up to 50.

    // verbose to view extra output
    final String _exploreEndpoint = "/v2/venues/explore";
    var recParams = baseParams;
    recParams['ll'] = _convertCoordinates(coordinates);
    recParams['radius'] =
        radius == null ? _milesToMeters(5) : radius.toString();
    recParams['query'] = query;
    recParams['limit'] = limit == null ? '25' : limit.toString();
    recParams['section'] = section;

    // generate the url
    var url = Uri.https(baseURL, _exploreEndpoint, recParams);

    if (verbose) {
      print("Endpoint: Explore (recommend) \nFull URL: $url \n${recParams}\n");
    }
    // send the request and return the body response
    var response = await requests.get(url);
    var body = json.decode(response.body);
    return body;
  }

  Future<Map> similar({var coordinates, var id, verbose: false}) async {
    // returns venues that are similar to the current one
    String venue_id;
    // if the user provided
    if (coordinates != null) {
      venue_id = await _getVenueID(coordinates);
    } else if (id != null) {
      venue_id = id;
    } else {
      throw Exception("Please provide either coordinates or a venue_id");
    }

    // build the url
    final String _similarEndpoint = "/v2/venues/${venue_id}/similar";
    var url = Uri.https(baseURL, _similarEndpoint, baseParams);
    if (verbose) {
      print("Endpoint: Similar \nFull URL: $url \n");
    }
    // send the request and get the results
    var response = await requests.get(url);
    var body = json.decode(response.body);
    return body;
  }

  Future<Map> details({var coordinates, var id, verbose: false}) async {
    String venue_id;
    // if the user provided
    if (coordinates != null) {
      venue_id = await _getVenueID(coordinates);
    } else if (id != null) {
      venue_id = id;
    } else {
      throw Exception("Please provide either coordinates or a venue_id");
    }

    // build the url
    final String _detailsEndpoint = "/v2/venues/$venue_id";
    var url = Uri.https(baseURL, _detailsEndpoint, baseParams);

    if (verbose) {
      print("Endpoint: Details \nFull URL: $url \n");
    }

    var response = await requests.get(url);
    Map body = json.decode(response.body);
    return body;
  }

  Future nextVenues({var coordinates, var id, verbose: false}) async {
    String venue_id;

    // if the user provided
    if (coordinates != null) {
      venue_id = await _getVenueID(coordinates);
    } else if (id != null) {
      venue_id = id;
    } else {
      throw Exception("Please provide either coordinates or a venue_id");
    }

    final String _nextEndpoint = "/v2/venues/$venue_id/nextvenues";
    var url = Uri.https(baseURL, _nextEndpoint, baseParams);

    if (verbose) {
      print("Endpoint: Next Venues \nFull URL: $url \n");
    }

    var response = await requests.get(url);
    var body = json.decode(response.body);
    return body;
  }

  Future _getVenueID(var coordinates) async {
    // input coordinates and get the venue ID
    Map results = await search(coordinates, limit: 1);
    var vID = results['response']['venues'][0]['id'];
    return vID;
  }

  String _convertCoordinates(dynamic coord) {
    var coordString;

    // handles for if coord is a map
    if (coord is Map) {
      // check for the keys
      var containsLatLng = coord.containsKey('lat') && coord.containsKey('lng');
      var containsLatitudeLongitude =
          coord.containsKey('latitude') && coord.containsKey('longitude');
      if (containsLatitudeLongitude) {
        coordString = "${coord['latitude']}, ${coord['longitude']}";
      } else if (containsLatLng) {
        coordString = "${coord['lat']}, ${coord['lng']}";
      } else {
        throw Exception(
            "coord map must either contain the keys 'lat' 'lng' or 'latitude' 'longitude' ");
      }
    } else if (coord is String) {
      coordString = coord;
    } else {
      // print(coord.runtimeType);
      throw Exception(
          "coord parameter must be a Map or String not ${coord.runtimeType}");
    }

    return coordString;
  }

  Future<Map> categories_() async {
    String categoryEndpoint = "/v2/venues/categories";
    var url = Uri.https(baseURL, categoryEndpoint, baseParams);
    var response = await requests.get(url);
    Map body = json.decode(response.body);
    return body;
  }

  Future<Map> trending(dynamic coordinates,
      {int radius, String query, int limit}) async {
    final _trendEndpoint = "/v2/venues/trending";
    var trendParams = baseParams;
    trendParams['radius'] =
        radius == null ? _milesToMeters(5) : radius.toString();
    trendParams['query'] = query;
    trendParams['limit'] = limit == null ? '25' : limit.toString();
    trendParams['ll'] = _convertCoordinates(coordinates);

    // generate the url
    var url = Uri.https(baseURL, _trendEndpoint, trendParams);
    var response = await requests.get(url);
    Map body = json.decode(response.body);
    return body;
  }

  Future<Map> getCategoryId(String category) async {
    // check to see if the categories contains the 'category' key
    var cat = await categories;

    // store values that are close to what your looking for
    List almost = [];

    // check to see if the map has the key in root
    if (cat.containsKey(category)) {
      // print("Key $category found");
      return {'value':cat[category]['id'], 'status':'key found'};
    } else {
      // if the key is not in root, check the children
      // print("Checking children");
      for (var key in cat.keys) {
        if (_almostKey(category, key)) {
          almost.add(key);
        }
        // check to see if the root has children
        if (cat[key]['has_children']) {
          // get the list of children
          var childrenList = cat[key]['children'];
          // check the children for the key
          for (var child in childrenList) {
            // hold the current key
            var currentKey = child.keys.toString();
            // if the key is found in the list of children
            if (child.containsKey(category)) {
              // print("Key $category found");

              return {'value': child[category], 'status': 'key found'};
              // if the key doesnt match but its similar to the target key
            } else if (_almostKey(category, currentKey)) {
              almost.add(currentKey);
            }
          }
        }
        // if they do, check the children for the key
        // if not, continur
      }
    }

    // if the children doesnt contain the key return that the Key cannot be found
    var message =
        "The key '$category' could not be found";
    return {'value': message, 'similar': almost ,'status': 'key not found'};
  }
}

  bool _almostKey(String targetKey, String key) {
    return key.contains(targetKey);
}
