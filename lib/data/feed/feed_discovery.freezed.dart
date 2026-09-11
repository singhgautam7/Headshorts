// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feed_discovery.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiscoveredFeed {

 String get url; String get title; bool get hasFullContent; int get itemsPerDay; String? get siteUrl;
/// Create a copy of DiscoveredFeed
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiscoveredFeedCopyWith<DiscoveredFeed> get copyWith => _$DiscoveredFeedCopyWithImpl<DiscoveredFeed>(this as DiscoveredFeed, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DiscoveredFeed;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiscoveredFeed&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.hasFullContent, _this.hasFullContent) || other.hasFullContent == _this.hasFullContent)&&(identical(other.itemsPerDay, _this.itemsPerDay) || other.itemsPerDay == _this.itemsPerDay)&&(identical(other.siteUrl, _this.siteUrl) || other.siteUrl == _this.siteUrl));
}


@override
int get hashCode {
  final _this = this as DiscoveredFeed;
  return Object.hash(runtimeType,_this.url,_this.title,_this.hasFullContent,_this.itemsPerDay,_this.siteUrl);
}

@override
String toString() {
  final _this = this as DiscoveredFeed;
  return 'DiscoveredFeed(url: ${_this.url}, title: ${_this.title}, hasFullContent: ${_this.hasFullContent}, itemsPerDay: ${_this.itemsPerDay}, siteUrl: ${_this.siteUrl})';
}


}

/// @nodoc
abstract mixin class $DiscoveredFeedCopyWith<$Res>  {
  factory $DiscoveredFeedCopyWith(DiscoveredFeed value, $Res Function(DiscoveredFeed) _then) = _$DiscoveredFeedCopyWithImpl;
@useResult
$Res call({
 String url, String title, bool hasFullContent, int itemsPerDay, String? siteUrl
});




}
/// @nodoc
class _$DiscoveredFeedCopyWithImpl<$Res>
    implements $DiscoveredFeedCopyWith<$Res> {
  _$DiscoveredFeedCopyWithImpl(this._self, this._then);

  final DiscoveredFeed _self;
  final $Res Function(DiscoveredFeed) _then;

/// Create a copy of DiscoveredFeed
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? title = null,Object? hasFullContent = null,Object? itemsPerDay = null,Object? siteUrl = freezed,}) {
  return _then(DiscoveredFeed(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,hasFullContent: null == hasFullContent ? _self.hasFullContent : hasFullContent // ignore: cast_nullable_to_non_nullable
as bool,itemsPerDay: null == itemsPerDay ? _self.itemsPerDay : itemsPerDay // ignore: cast_nullable_to_non_nullable
as int,siteUrl: freezed == siteUrl ? _self.siteUrl : siteUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DiscoveredFeed].
extension DiscoveredFeedPatterns on DiscoveredFeed {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiscoveredFeed value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiscoveredFeed() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiscoveredFeed value)  $default,){
final _that = this;
switch (_that) {
case _DiscoveredFeed():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiscoveredFeed value)?  $default,){
final _that = this;
switch (_that) {
case _DiscoveredFeed() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  String title,  bool hasFullContent,  int itemsPerDay,  String? siteUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiscoveredFeed() when $default != null:
return $default(_that.url,_that.title,_that.hasFullContent,_that.itemsPerDay,_that.siteUrl);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  String title,  bool hasFullContent,  int itemsPerDay,  String? siteUrl)  $default,) {final _that = this;
switch (_that) {
case _DiscoveredFeed():
return $default(_that.url,_that.title,_that.hasFullContent,_that.itemsPerDay,_that.siteUrl);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  String title,  bool hasFullContent,  int itemsPerDay,  String? siteUrl)?  $default,) {final _that = this;
switch (_that) {
case _DiscoveredFeed() when $default != null:
return $default(_that.url,_that.title,_that.hasFullContent,_that.itemsPerDay,_that.siteUrl);case _:
  return null;

}
}

}

/// @nodoc


class _DiscoveredFeed implements DiscoveredFeed {
  const _DiscoveredFeed({required this.url, required this.title, required this.hasFullContent, required this.itemsPerDay, this.siteUrl});
  

@override final  String url;
@override final  String title;
@override final  bool hasFullContent;
@override final  int itemsPerDay;
@override final  String? siteUrl;

/// Create a copy of DiscoveredFeed
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiscoveredFeedCopyWith<_DiscoveredFeed> get copyWith => __$DiscoveredFeedCopyWithImpl<_DiscoveredFeed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiscoveredFeed&&(identical(other.url, url) || other.url == url)&&(identical(other.title, title) || other.title == title)&&(identical(other.hasFullContent, hasFullContent) || other.hasFullContent == hasFullContent)&&(identical(other.itemsPerDay, itemsPerDay) || other.itemsPerDay == itemsPerDay)&&(identical(other.siteUrl, siteUrl) || other.siteUrl == siteUrl));
}


@override
int get hashCode {
    return Object.hash(runtimeType,url,title,hasFullContent,itemsPerDay,siteUrl);
}

@override
String toString() {
    return 'DiscoveredFeed(url: $url, title: $title, hasFullContent: $hasFullContent, itemsPerDay: $itemsPerDay, siteUrl: $siteUrl)';
}


}

/// @nodoc
abstract mixin class _$DiscoveredFeedCopyWith<$Res> implements $DiscoveredFeedCopyWith<$Res> {
  factory _$DiscoveredFeedCopyWith(_DiscoveredFeed value, $Res Function(_DiscoveredFeed) _then) = __$DiscoveredFeedCopyWithImpl;
@override @useResult
$Res call({
 String url, String title, bool hasFullContent, int itemsPerDay, String? siteUrl
});




}
/// @nodoc
class __$DiscoveredFeedCopyWithImpl<$Res>
    implements _$DiscoveredFeedCopyWith<$Res> {
  __$DiscoveredFeedCopyWithImpl(this._self, this._then);

  final _DiscoveredFeed _self;
  final $Res Function(_DiscoveredFeed) _then;

/// Create a copy of DiscoveredFeed
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? title = null,Object? hasFullContent = null,Object? itemsPerDay = null,Object? siteUrl = freezed,}) {
  return _then(_DiscoveredFeed(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,hasFullContent: null == hasFullContent ? _self.hasFullContent : hasFullContent // ignore: cast_nullable_to_non_nullable
as bool,itemsPerDay: null == itemsPerDay ? _self.itemsPerDay : itemsPerDay // ignore: cast_nullable_to_non_nullable
as int,siteUrl: freezed == siteUrl ? _self.siteUrl : siteUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
