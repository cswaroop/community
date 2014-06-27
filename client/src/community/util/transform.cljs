(ns community.util.transform)

(defn transformed? [data]
  (:transformed? (meta data)))

(defn mark-transformed [data]
  ^:transformed? data)

(defn transform [data transforms]
  (if (or (not (map? data)) (transformed? data))
    data
    (into {}
      (for [[k v] data]
        (if (transformed? v)
          [k v]
          (let [t (get transforms k identity)]
            [k (mark-transformed (transform (t v) transforms))]))))))

(defprotocol ITransformer
  (-add-transform [_ key transform]))

(deftype Transformer [!transforms]
  ITransformer
  (-add-transform [_ key transform]
    (swap! !transforms assoc key transform))

  ILookup
  (-lookup [_ k]
    (get @!transforms k))

  IFn
  (-invoke [_ data]
    (transform data @!transforms))

  (-invoke [_ key data]
    (get (transform {key data} @!transforms) key)))

(defn transformer []
  (Transformer. (atom {})))
