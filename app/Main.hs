module Main (main) where

import Data.Aeson (decode)
import Data.Maybe (fromJust)
import Lib
import RIO
import qualified RIO.ByteString.Lazy as B
import RIO.FilePath
import System.Environment (lookupEnv)

getLogLevelFromEnv :: IO LogLevel
getLogLevelFromEnv = do
    envValue <- lookupEnv "LOG_LEVEL"
    return $ case envValue of
        Just "debug" -> LevelDebug
        Just "info" -> LevelInfo
        Just "warn" -> LevelWarn
        Just "error" -> LevelError
        _ -> LevelInfo -- Default log level if not set or invalid value

main :: IO ()
main = do
    homePath <- fromJust <$> lookupEnv "HOME"
    conf <- fromJust <$> readJsonFile (homePath </> ".rpc-gateway.json")
    logOpts_ <- logOptionsHandle stdout True
    let logOpts = setLogMinLevelIO getLogLevelFromEnv logOpts_
    nodes <- initRoundRobin conf.nodes
    withLogFunc logOpts $ \logFunc -> do
        let
            app = App {logFunc, nodes}
            host = conf.host
            port = conf.port
        runRIO app $ runApp host port

-- runRIO app f

readJsonFile :: FilePath -> IO (Maybe Config)
readJsonFile filePath = do
    jsonData <- B.readFile filePath
    let ymlConfig = decode jsonData
    return ymlConfig
