module Vote
    exposing
        ( Id
        , Vote
        , encode
        , eventForPersonId
        , withEventsDecoder
        , withoutEventsDecoder
        )

import Date exposing (Date)
import Date.Extra
import Json.Decode as D
import Json.Encode as E
import List.Extra
import Policy
import RemoteData exposing (RemoteData(..), WebData)
import Tagged exposing (Tagged)
import VoteEvent exposing (PersonId, VoteEvent)


type alias Vote =
    { id : Id
    , text : String
    , actionsYes : String
    , actionsNo : String
    , date : Date
    , policyIds : List Policy.Id
    , voteEvents : WebData (List VoteEvent)
    }


type alias Id =
    Tagged IdTag Int


type IdTag
    = IdTag


encode : Maybe PersonId -> Vote -> E.Value
encode selectedPersonId vote =
    case vote.voteEvents of
        Success events ->
            E.list (List.map (VoteEvent.encode selectedPersonId) events)

        _ ->
            -- XXX Handle this better.
            E.null


eventForPersonId : Vote -> Maybe PersonId -> Maybe VoteEvent
eventForPersonId vote personId =
    case ( vote.voteEvents, personId ) of
        ( Success events, Just personId_ ) ->
            List.Extra.find
                (.personId >> (==) personId_)
                events

        _ ->
            Nothing


withoutEventsDecoder : D.Decoder (Maybe Vote)
withoutEventsDecoder =
    createDecoder (D.succeed NotAsked)


withEventsDecoder : D.Decoder (Maybe Vote)
withEventsDecoder =
    let
        voteEventsDecoder =
            D.list VoteEvent.decoder
                |> D.map Success
                |> D.field "voteEvents"
    in
    createDecoder voteEventsDecoder


createDecoder : D.Decoder (WebData (List VoteEvent)) -> D.Decoder (Maybe Vote)
createDecoder voteEventsDecoder =
    D.map7 createVote
        (D.field "id" D.int |> D.map Tagged.tag)
        (D.field "text" D.string)
        (D.field "actions_yes" D.string)
        (D.field "actions_no" D.string)
        (D.field "date" D.string)
        (D.field "policyIds" (D.list (D.int |> D.map Policy.id)))
        voteEventsDecoder


createVote : Id -> String -> String -> String -> String -> List Policy.Id -> WebData (List VoteEvent) -> Maybe Vote
createVote id text actionsYes actionsNo date policyIds voteEvents =
    case Date.Extra.fromIsoString date of
        Just date_ ->
            Vote
                id
                text
                actionsYes
                actionsNo
                date_
                policyIds
                voteEvents
                |> Just

        Nothing ->
            Nothing
