module Lib
    ( runApp
    , App (..)
    , RoundRobinState
    , initRoundRobin
    , Config (..)
    ) where

---

import           RIO
import           RIO.List
import           RIO.List.Partial         (head, tail)
import qualified RIO.Text                 as T

import           Data.Aeson               (FromJSON)
import           Network.HTTP.Simple      (getResponseBody, getResponseHeaders, getResponseStatus,
                                           httpLBS, parseRequest, setRequestBodyLBS,
                                           setRequestHeaders, setRequestMethod)
import           Network.HTTP.Types       (Status (statusCode), status200, status502)
import           Network.Wai              (Application, lazyRequestBody, responseLBS)
import qualified Network.Wai              as Wai
import           Network.Wai.Handler.Warp (Port, defaultSettings, runSettings, setHost, setPort)

---

runApp :: String -> Port -> RIO App ()
runApp host port = do
    logInfo $ display $ "Starting Load Balancer on http://" <> T.pack host <> ":" <> showT port
    app <- ask
    let settings = setHost (fromString host) $ setPort port defaultSettings
    liftIO $ runSettings settings $ loadBalancer app

data App = App
    { logFunc :: !LogFunc
    , nodes   :: RoundRobinState
    }

data Config = Config
    { nodes :: [Text]
    , host  :: String
    , port  :: Port
    }
    deriving (Show, Generic, FromJSON)

instance HasLogFunc App where
    logFuncL = lens (\x -> x.logFunc) (\x y -> x {logFunc = y})

type RoundRobinState = IORef [Text]

initRoundRobin :: [Text] -> IO RoundRobinState
initRoundRobin nodes = newIORef (cycle nodes)

loadBalancer :: App -> Application
loadBalancer app req respond = do
    resp <- runRIO app $ go retryCount
    respond resp
    where
        retryCount = 4

        go :: Integer -> RIO App Wai.Response
        go retry = do
            node <- getNextNode
            resp <- proxyRequest node req
            let status = Wai.responseStatus resp
            if status == status200
                then do
                    logInfo $ display_ $
                        "Response is ok from "
                            <> node
                            <> ", status code: "
                            <> showT status.statusCode
                    return resp
                else do
                    logInfo $ display_ $
                        "Response is not ok from"
                            <> node
                            <> " with status code: "
                            <> showT status.statusCode
                    if retry > 0
                        then do
                            logInfo "Trying next node"
                            go (retry - 1)
                        else do
                            logWarn $ display_ $
                                "Exhausted all "
                                    <> showT retryCount
                                    <> " retries to get a 200 OK response from nodes. Last received status: "
                                    <> showT status
                                    <> ". Abandoning operation"
                            return $ responseLBS status502 [] ""

-- https://github.com/snoyberg/http-client/blob/master/TUTORIAL.md
proxyRequest :: Text -> Wai.Request -> RIO App Wai.Response
proxyRequest backend req = do
    req__ <- parseRequest $ T.unpack backend
    reqBody <- liftIO $ lazyRequestBody req
    let
        headers = [("content-type", "application/json")]
        req_
            = setRequestMethod  "POST"
            $ setRequestBodyLBS reqBody
            $ setRequestHeaders headers
            $ req__
    logInfo $ display_ req_
    resp <- httpLBS req_
    logInfo $ display_ resp
    let
        respHeaders = getResponseHeaders resp
        respBody    = getResponseBody resp
        status      = getResponseStatus resp
    pure $ responseLBS status respHeaders respBody

getNextNode :: RIO App Text
getNextNode = do
    app <- ask
    atomicModifyIORef app.nodes $ \nodes -> (tail nodes, head nodes)

-------------------------------------------------------------------------------
-- Utiles

showT :: (Show a) => a -> Text
showT = T.pack . show

display_ x = displayShow x
