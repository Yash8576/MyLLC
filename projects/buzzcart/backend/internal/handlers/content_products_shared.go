package handlers

// contentProductsJSONSelect aggregates tagged products into a JSON array,
// aliased as `products`. Callers must join content_products/products as
// `cp`/`prod`, then GROUP BY the other selected columns.
const contentProductsJSONSelect = `
COALESCE(
	jsonb_agg(
		DISTINCT jsonb_build_object(
			'id', prod.id,
			'title', prod.title,
			'price', prod.price,
			'image', COALESCE((
				SELECT pi.image_url
				FROM product_images pi
				WHERE pi.product_id = prod.id
				ORDER BY pi.is_primary DESC, pi.display_order ASC, pi.created_at ASC
				LIMIT 1
			), '')
		)
	) FILTER (WHERE prod.id IS NOT NULL),
	'[]'::jsonb
) AS products`
