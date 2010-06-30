-module(riak_search_schema, [Name, Version, DefaultField, FieldsAndFacets, DynamicFields, DefaultOp, AnalyzerFactory]).
-export([
    %% Properties...
    name/0,
    set_name/1,
    version/0,
    fields_and_facets/0,
    facets/0,
    fields/0,
    default_field/0,
    set_default_field/1,
    default_op/0,
    analyzer_factory/0,
    set_default_op/1,

    %% Field properties...
    field_name/1,
    field_type/1,
    is_field_required/1,
    is_field_facet/1,
    field_types/0,

    %% Field lookup
    find_field_or_facet/1,
    find_field/1,
    find_facet/1,

    %% Validation
    validate_commands/2
]).

-include("riak_search.hrl").

name() ->
    Name.

set_name(NewName) ->
    ?MODULE:new(NewName, Version, DefaultField, FieldsAndFacets, DynamicFields, DefaultOp, AnalyzerFactory).

version() ->
    Version.

fields_and_facets() ->
    FieldsAndFacets.

fields() ->
    [X || X <- FieldsAndFacets, X#riak_search_field.facet == false].

facets() ->
    [X || X <- FieldsAndFacets, X#riak_search_field.facet == true].

default_field() ->
    DefaultField.

analyzer_factory() when is_list(AnalyzerFactory) ->
    list_to_binary(AnalyzerFactory);
analyzer_factory() ->
    AnalyzerFactory.

set_default_field(NewDefaultField) ->
    ?MODULE:new(Name, Version, NewDefaultField, FieldsAndFacets, DynamicFields, DefaultOp, AnalyzerFactory).

default_op() ->
    DefaultOp.

set_default_op(NewDefaultOp) ->
    ?MODULE:new(Name, Version, DefaultField, FieldsAndFacets, DynamicFields, NewDefaultOp, AnalyzerFactory).

field_name(Field) ->
    Field#riak_search_field.name.

field_type(Field) ->
    Field#riak_search_field.type.

is_field_required(Field) ->
    Field#riak_search_field.required == true.

is_field_facet(Field) ->
    Field#riak_search_field.facet == true.

field_types() ->
    FTypes0 = [{Field#riak_search_field.name,
                Field#riak_search_field.type} || Field <- fields()],
    case proplists:get_value(default_field(), fields()) of
        undefined ->
            FTypes0;
        Field ->
            [{default,
              Field#riak_search_field.type}|FTypes0]
    end.


%% Return the field or facet matching the specified name, or 'undefined'.
find_field_or_facet(FName) ->
    case lists:keyfind(FName, #riak_search_field.name, FieldsAndFacets) of
        Field when is_record(Field, riak_search_field) ->
            Field;
        false ->
            undefined
        end.

%% Return the field matching the specified name, or 'undefined'
find_field(FName) ->
    case find_field_or_facet(FName) of
        undefined ->
            case find_dynamic_field(FName) of
                undefined ->
                    undefined;
                Field ->
                    Field
            end;
        Field ->
            case Field#riak_search_field.facet /= true of
                true  -> Field;
                false -> undefiend
            end
    end.

%% Return the facet matching the specified name, or 'undefined'
find_facet(FName) ->
    Field = find_field_or_facet(FName),
    case Field#riak_search_field.facet == true of
        true  -> Field;
        false -> undefiend
    end.

%% Verify that the schema names match. If so, then validate required
%% and optional fields. Otherwise, return an error.
validate_commands(add, Docs) ->
    Required = [F || F <- FieldsAndFacets, F#riak_search_field.required =:= true],
    validate_required_fields(Docs, Required);
validate_commands(_, _) ->
    ok.

%% @private
%% Validate for required fields in the list of documents.
%% Return 'ok', or an {error, Error} if a field is missing.
validate_required_fields([], _) ->
    ok;
validate_required_fields([Doc|Rest], Required) ->
    case validate_required_fields_1(Doc, Required) of
        ok -> validate_required_fields(Rest, Required);
        Other -> Other
    end.

%% @private
%% Validate required fields in a single document.
%% Return 'ok' or an {error, Error} if a field is missing.
validate_required_fields_1(_, []) ->
    ok;
validate_required_fields_1(Doc, [Field|Rest]) ->
    FieldName = Field#riak_search_field.name,
    case dict:find(FieldName, Doc) of
        {ok, _Value} ->
            validate_required_fields_1(Doc, Rest);
        error ->
            {error, {reqd_field_missing, FieldName}}
    end.

%% @private
%% Finds a dynamic field based on name and
%% pattern matching
find_dynamic_field(FName) ->
    case locate_match(FName, DynamicFields) of
        {ok, Field} ->
            Field#riak_search_field{name=FName};
        undefined ->
            undefined
    end.

%% @private
%% Loops thru dynamic fields looking for a match
locate_match(_FName, []) ->
    undefined;
locate_match(FName, [H|T]) ->
    case re:run(FName, H#riak_search_field.name) of
        {match, _} ->
            {ok, H};
        nomatch ->
            locate_match(FName, T)
    end.
