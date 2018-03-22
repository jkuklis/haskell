module RegExtra where
import Mon
import Reg
import Data.List

data AB = A | B deriving(Eq,Ord,Show)

infix 4 ===
class Equiv a where
  (===) :: a -> a -> Bool

instance (Eq c) => Equiv (Reg c) where
   r1 === r2 = (simpl r1) == (simpl r2)

instance Mon (Reg c) where
  m1 = Eps
  x <> y = x :> y
  
simpl :: Eq c => Reg c -> Reg c
simpl x = case x of
    Many(y) -> let s = simpl(y) in case s of
        Eps -> s
        Empty -> Eps
        Many(_) -> s
        _ -> Many(s)
    (l :> r) -> let g = gather_c x [] in if (has_Empty g)
        then Empty
        else roll_c (remove_Eps g)
    (l :| r) -> let g = nub (gather_a x []) in roll_a (remove_Empty g) 
    _ -> x

gather_c :: Eq c => Reg c -> [Reg c] -> [Reg c]
gather_c x acc = case x of
    (l :> r) -> gather_c l (gather_c r acc)
    _ -> simpl(x) : acc
    
gather_a :: Eq c => Reg c -> [Reg c] -> [Reg c]
gather_a x acc = case x of
    (l :| r) -> gather_a l (gather_a r acc)
    _ -> simpl(x) : acc    
    
has_Empty :: [Reg c] -> Bool
has_Empty g = case g of
    [] -> False
    (x:xs) -> case x of
        Empty -> True
        _ -> has_Empty xs   

remove_Eps :: [Reg c] -> [Reg c]
remove_Eps g = case g of
    [] -> []
    (x:xs) -> case x of
        Eps -> remove_Eps xs
        _ -> x : (remove_Eps xs)
        
remove_Empty :: [Reg c] -> [Reg c]
remove_Empty g = case g of
    [] -> []
    (x:xs) -> case x of
        Empty -> remove_Empty xs
        _ -> x : (remove_Empty xs)

roll_c :: [Reg c] -> Reg c
roll_c g = case g of
    [] -> Eps
    (x:xs) -> case xs of
        [] -> x
        _ -> x :> (roll_c xs)
        
roll_a :: [Reg c] -> Reg c
roll_a g = case g of
    [] -> Empty
    (x:xs) -> case xs of
        [] -> x
        _ -> x :| (roll_a xs)        

nullable :: Reg c -> Bool
nullable x = case x of
    Many(_) -> True
    Empty -> False
    Eps -> True
    Lit c -> False
    (x :| y) -> (nullable x) || (nullable y)
    (x :> y) -> (nullable x) && (nullable y)

empty :: Eq c => Reg c -> Bool 
empty r = case simpl(r) of
    Empty -> True
    _ -> False    

der :: Eq c => c -> Reg c -> Reg c
der c r = case r of
    Lit d -> if d == c then Eps else Empty
    Eps -> Empty
    Empty -> Empty
    Many(y) -> simpl((der c y) :> Many(y))
    (x :| y) -> simpl((der c x) :| (der c y))
    (x :> y) -> if (nullable x)
        then simpl(((der c x) :> y) :| (der c y))
        else simpl((der c x) :> y)

ders :: Eq c => [c] -> Reg c -> Reg c
ders c r = case c of
    [] -> r
    (x:xs) -> ders xs (der x r)

accepts :: Eq c => Reg c -> [c] -> Bool
accepts r w = if w == [] 
    then False 
    else if nullable (ders w r)
        then True
        else False

mayStart :: Eq c => c -> Reg c -> Bool
mayStart c r = (accepts r [c]) || not(empty (der c r)) 

match :: Eq c => Reg c -> [c] -> Maybe [c]
match r w = case (match_h r w [] Nothing) of
    Nothing -> Nothing
    Just p -> Just (reverse p)

match_h :: Eq c => Reg c -> [c] -> [c] -> Maybe [c] -> Maybe[c]
match_h r w acc prev =
    let prev' = if nullable r then Just acc else prev in
        case w of
            [] -> prev'
            (x:xs) -> match_h (der x r) xs (x : acc) prev'     

search :: Eq c => Reg c -> [c] -> Maybe [c]
search r w = 
    if check_eps r w then Just [] else
        case w of
        [] -> if nullable r 
            then Just [] 
            else Nothing
        (x:xs) -> let m = match r w in case m of
            Nothing -> search r xs
            _ -> m

check_eps :: Eq c => Reg c -> [c] -> Bool
check_eps r w =
    case w of
        [] -> False
        (x:xs) -> if (nullable r) && (match r w == Nothing)
            then True
            else False

findall :: Eq c => Reg c -> [c] -> [[c]]
findall r w = let rev = reverse (findall_h r w []) in 
    if (match r w == Nothing) && (nullable r) 
        then ([] : rev)
        else rev
    
findall_h :: Eq c => Reg c -> [c] -> [[c]] -> [[c]]
findall_h r w acc = case w of
    [] -> acc
    (x:xs) -> if (mayStart x r)
        then let m = match r w in case m of
            Just p -> let l = length p - 1 in findall_h r (drop l xs) (p : acc)
            Nothing -> findall_h r xs acc
        else findall_h r xs acc

char :: Char -> Reg Char
char = Lit

string :: [Char] -> Reg Char
string = foldr1 (:>) . map Lit

alts :: [Char] -> Reg Char
alts = foldr1 (:|) . map Lit

letter = alts ['a'..'z'] :| alts ['A'..'Z']
digit = alts ['0'..'9']
number = digit :> Many digit
ident = letter :> Many (letter :| digit)

many1 r = r :> Many r
