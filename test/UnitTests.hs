module UnitTests(
  allUnitTests
  ) where

import Test.HUnit

import qualified Data.Graph.Inductive.Graph as ING
import qualified Data.Graph.Inductive.PatriciaTree as FGR

import Data.List(foldl', sort)

import Translate(stringToSyntaxGraph)
import TranslateCore(syntaxGraphToFglGraph, SyntaxGraph(..), Reference)
import Types(SgNamedNode, Edge(..), SyntaxNode(..),
             IngSyntaxGraph, NodeName(..), LikeApplyFlavor(..), NameAndPort(..))
import qualified GraphAlgorithms
import Util(fromMaybeError)

-- Unit Test Helpers --

assertAllEqual :: (Eq a, Show a) => [a] -> Test
assertAllEqual items = case items of
  [] -> TestCase $ assertFailure "assertAllEqual: argument is empty list"
  (first : rest) -> TestList $ fmap (first ~=?) rest

assertEqualSyntaxGraphs :: [String] -> Test
assertEqualSyntaxGraphs ls = assertAllEqual $ fmap (renameGraph . stringToSyntaxGraph) ls

-- BEGIN renameGraph --

-- TODO Implement renameSyntaxNode
renameSyntaxNode :: [(NodeName, NodeName)] -> SyntaxNode -> Int  -> (SyntaxNode, Int)
renameSyntaxNode nameMap node counter = (node, counter)

renameNode :: ([SgNamedNode], [(NodeName, NodeName)], Int) -> SgNamedNode -> ([SgNamedNode], [(NodeName, NodeName)], Int)
renameNode state@(renamedNodes, nameMap, counter) node@(nodeName, syntaxNode) = case lookup nodeName nameMap of
  Nothing -> (newNamedNode:renamedNodes, newNameMap, newCounter) where
    newNodeName = NodeName counter
    newNameMap = (nodeName, newNodeName) : nameMap
    (newSyntaxNode, newCounter) = renameSyntaxNode newNameMap syntaxNode (counter + 1)
    newNamedNode = (newNodeName, newSyntaxNode)
  Just _ -> error $ "renameNode: node already in name map. State = " ++ show state ++ " Node = " ++ show node

renameNamePort :: [(NodeName, NodeName)] -> NameAndPort -> NameAndPort
renameNamePort nameMap nameAndPort@(NameAndPort name port) = NameAndPort newName port where
  newName = fromMaybeError errorStr $ lookup name nameMap
  errorStr = "renameNamePort: name not found. name = " ++ show name ++ "\nNameAndPort = " ++ show nameAndPort ++ "\nNameMap = " ++ show nameMap

renameEdge :: [(NodeName, NodeName)] -> Edge -> Edge
renameEdge nameMap (Edge options ends (np1, np2)) =
  Edge options ends (renameNamePort nameMap np1, renameNamePort nameMap np2)

renameSource :: [(NodeName, NodeName)] -> (String, Reference) -> (String, Reference)
renameSource nameMap (str, ref) = (str, newRef) where
  newRef = case ref of
    Left _ -> ref
    Right namePort@(NameAndPort _ _) -> Right $ renameNamePort nameMap namePort

-- TODO Rename sinks and embedMap
-- TODO Add unit tests for renameGraph
renameGraph :: SyntaxGraph -> SyntaxGraph
renameGraph (SyntaxGraph nodes edges sinks sources embedMap) =
  SyntaxGraph (sort renamedNodes) renamedEdges sinks renamedSources embedMap
  where
    (renamedNodes, nameMap, _) = foldl' renameNode ([], [], 0) nodes
    renamedEdges = sort $ fmap (renameEdge nameMap) edges
    renamedSources = sort $ fmap (renameSource nameMap) sources
  
-- END renameGraph

-- END Unit Test Helpers --


-- 0:(toName "app02",ApplyNode 1)->[]
-- 1:(toName "f0",LiteralNode "f")->[(Edge {edgeOptions = [], edgeEnds = (EndNone,EndNone), edgeConnection = (NameAndPort (toName "f0") Nothing,NameAndPort (toName "app02") (Just 0))},0)]
-- 2:(toName "x1",LiteralNode "x")->[(Edge {edgeOptions = [], edgeEnds = (EndNone,EndNone), edgeConnection = (NameAndPort (toName "x1") Nothing,NameAndPort (toName "app02") (Just 2))},0)]
-- 3:(toName "y3",NameNode "y")->[(Edge {edgeOptions = [], edgeEnds = (EndNone,EndNone), edgeConnection = (NameAndPort (toName "y3") Nothing,NameAndPort (toName "app02") (Just 1))},0)]
singleApplyGraph :: FGR.Gr SgNamedNode Edge
singleApplyGraph = syntaxGraphToFglGraph $ stringToSyntaxGraph "y = f x"

makeTreeRootTest :: (String, [Maybe SgNamedNode], String) -> Test
makeTreeRootTest (testName, expected, haskellString) = TestCase $ assertEqual testName expected actual where
  actual = fmap (ING.lab graph) treeRoots
  graph = syntaxGraphToFglGraph $ stringToSyntaxGraph haskellString
  treeRoots = GraphAlgorithms.findTreeRoots graph

treeRootTests :: Test
treeRootTests = TestList $ fmap makeTreeRootTest treeRootTestList where
  treeRootTestList = [
    ("single apply", [Just (NodeName 2, LikeApplyNode ApplyNodeFlavor 1)], "y = f x"),
    -- TODO Fix test below
    ("double apply", [Just (NodeName 3, LikeApplyNode ComposeNodeFlavor 2)], "y = f (g x)"),
    ("recursive apply", [Just (NodeName 3,LikeApplyNode ComposeNodeFlavor 2)], "y = f (g y)")
    ]

makeChildCanBeEmbeddedTest ::
  ING.Graph gr =>
  (String, IngSyntaxGraph gr, ING.Node, Bool) -> Test
makeChildCanBeEmbeddedTest (testName, graph, node, expected) =TestCase $ assertEqual testName expected canBeEmbedded where
  canBeEmbedded = GraphAlgorithms.nodeWillBeEmbedded graph node

-- TODO Add more cases for childCanBeEmbeddedTests
-- TODO Fix these tests
childCanBeEmbeddedTests :: Test
childCanBeEmbeddedTests = TestList $ fmap makeChildCanBeEmbeddedTest childCanBeEmbeddedList where
  childCanBeEmbeddedList = [
    ("single apply, ap", singleApplyGraph, 0, False),
    ("single apply, f", singleApplyGraph, 1, True),
    ("single apply, x", singleApplyGraph, 2, True),
    ("single apply, y", singleApplyGraph, 3, False)
    ]

collapseUnitTests :: Test
collapseUnitTests = TestList[
  TestLabel "findTreeRoots" treeRootTests
  --TestLabel "childCanBeEmbedded" childCanBeEmbeddedTests
  ]

-- Translate unit tests

dollarTests = TestList [
  TestLabel "dollarTests1" $ assertEqualSyntaxGraphs [
      "y = f x",
      "y = f $ x"
      ]
  ,
  TestLabel "dollarTests2" $ assertEqualSyntaxGraphs [
      "y = f (g x)",
      "y = f $ (g x)",
      "y = f $ g  $ x",
      "y = f (g  $ x)"
      ]
  ,
  TestLabel "dollarTests3" $ assertEqualSyntaxGraphs [
      "y = f 1 (g 2)",
      "y = f 1 $ g 2"
      ]
  ]

composeApplyTests = TestList [
  TestLabel "composeApplyTests1" $ assertEqualSyntaxGraphs [
      "y = f (g x)",
      "y = (f . g) x",
      "y = f . g $ x"
      ]
  ,
  TestLabel "composeApplyTests2" $ assertEqualSyntaxGraphs [
      "y = f3 (f2 (f1 x))",
      "y = f3 . f2 . f1 $ x",
      "y = (f3 . f2 . f1) x"
      ]
  ]

infixTests = TestList [
  TestLabel "infixTests1" $ assertEqualSyntaxGraphs [
      "y = (+) 1 2",
      "y = ((+) 1) 2",
      "y = 1 + 2",
      "y = (1 +) 2"
      ]
  ,
  TestLabel "infixTests2" $ assertEqualSyntaxGraphs [
      "y = f (1 +) 2",
      "y = f ((+) 1) 2"
      ]
  ]

letTests = TestList [
  TestLabel "letTests1" $ assertEqualSyntaxGraphs [
      "y = f 1",
      "y = let x = 1 in f x"
      ]
  ]

-- Yes, the commas get their own line
translateUnitTests :: Test
translateUnitTests = TestList [
  TestLabel "fmapTest" $ assertEqualSyntaxGraphs [
      "y = fmap f x",
      "y = f <$> x"
      ]
  ,
  TestLabel "dollarTests" dollarTests
  ,
  TestLabel "composeApplyTests" composeApplyTests
  ,
  TestLabel "infixTests" infixTests
  , TestLabel "letTests" letTests
  ]

allUnitTests :: Test
allUnitTests = TestList[
  TestLabel "collapseUnitTests" collapseUnitTests,
  TestLabel "translateTests" translateUnitTests
  ]