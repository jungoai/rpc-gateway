module JsonRpc
    ( sendJsonRpcRequest
    ) where

---

import           RIO
import qualified RIO.ByteString.Lazy as LBS

import           Data.Aeson          (FromJSON, ToJSON, encode)
import           Network.HTTP.Simple (Response, httpLBS, parseRequest, setRequestBodyLBS,
                                      setRequestMethod)

---

data JsonRpcRequest = JsonRpcRequest
    { jsonrpc :: Text
    , method  :: Text
    , params  :: [Text]
    , id      :: Int
    }
    deriving (Show, Generic, FromJSON, ToJSON)

sendJsonRpcRequest :: Text -> [Text] -> IO (Response LBS.ByteString)
sendJsonRpcRequest method params = do
    let
        requestBody = JsonRpcRequest "2.0" method params 1
        jsonRequest = encode requestBody
    req_ <- parseRequest "https://example.com/rpc" -- Replace with your server URL
    let req = setRequestMethod "POST"
            $ setRequestBodyLBS jsonRequest
            $ req_
    httpLBS req
