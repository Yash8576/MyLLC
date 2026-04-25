# BuzzCart: A Trust-Centered Social Commerce Platform with Verified Social Reviews and RAG-Based Product Understanding

## Major Project Report

Prepared in the context of the BuzzCart codebase  
Date: April 23, 2026

---

## Table of Contents

1. Introduction  
2. Problem Statement  
3. Motivation  
   3.1 The Trust Problem in Online Reviews  
   3.2 Social Commerce Context  
   3.2.1 Buyers  
   3.2.2 Sellers  
   3.2.3 Platforms  
   3.3 Inadequacy of Existing Solutions  
   3.4 The Technology Opportunity  
4. Existing Solutions and Related Work  
   4.1 Traditional Ecommerce Review Systems  
   4.2 Social Commerce Platforms  
   4.3 Retrieval-Augmented Generation for Product Question Answering  
   4.4 Real-Time Commerce and Messaging Platforms  
5. BuzzCart System Design  
   5.1 High-Level Architecture  
   5.2 User Flow  
   5.3 Trust-Centered Review Flow  
   5.4 Database Schema  
   5.5 API Design  
   5.6 Key Design Decisions  
6. Implementation  
   6.1 Frontend: Flutter Application  
   6.1.1 Authentication Flow  
   6.1.2 Product Discovery and Shop Experience  
   6.1.3 Review and Buyer Visibility Interfaces  
   6.1.4 Product Document Chat Experience  
   6.2 Backend: Go Server  
   6.2.1 Deployment Environment  
   6.2.2 Core API Modules  
   6.2.3 Review Ranking and Verified Purchase Enforcement  
   6.2.4 Real-Time Messaging Pipeline  
   6.3 Storage, Database, and Cache Integration  
   6.3.1 PostgreSQL  
   6.3.2 Firebase Storage  
   6.3.3 Redis  
   6.4 Product Document RAG Service  
   6.4.1 Document Ingestion and Indexing  
   6.4.2 Hybrid Retrieval and Reranking  
   6.4.3 Grounded Response Generation  
7. Evaluation  
   7.1 Functional Coverage  
   7.2 Results  
   7.3 Performance and Scalability Considerations  
8. Conclusion and Future Work  
References

---

## 1. Introduction

BuzzCart is a full-stack social commerce platform that combines ecommerce, short-form content, trusted reviews, real-time messaging, and AI-assisted product understanding into one unified product experience. Instead of treating shopping as a simple catalog search process, BuzzCart presents product discovery as a socially influenced workflow in which users browse products through posts, videos, reels, shop listings, and direct interactions with other users.

The project is implemented as a multi-service system. The frontend is built in Flutter and supports responsive app-style navigation across web and device targets. The main backend is written in Go using Gin and provides authentication, product APIs, review workflows, cart and checkout, social feeds, upload endpoints, and real-time messaging. Persistent data is stored in PostgreSQL, media and product documents are managed through Firebase Storage, Redis is used for selected caching operations, and a dedicated Python FastAPI microservice provides Retrieval-Augmented Generation (RAG) for product-document question answering.

BuzzCart is especially meaningful because it addresses two practical weaknesses of many online commerce systems. The first is the trust gap in review systems, where reviews often appear as anonymous, flat, easily manipulated text with little social or transactional context. The second is the product-understanding gap, where users are expected to read lengthy technical documents or rely on generic chatbots that may produce unsupported answers. BuzzCart addresses both by prioritizing reviews from known people and verified buyers, and by enabling document-grounded AI answers for each product.

This report follows the structural pattern of the supplied reference project report, but the content is fully adapted to the BuzzCart project and grounded in the architecture, database schema, API design, UI workflows, and implementation observed in the current codebase.

## 2. Problem Statement

Modern digital marketplaces face two major issues that directly affect user confidence and purchase conversion.

The first issue is the low trustworthiness of product reviews. On many platforms, reviews are shown without meaningful context. A user may not know whether the reviewer actually bought the product, whether the reviewer is socially relevant to them, whether the review has been moderated, or whether other users found it helpful. This creates a weak trust model and makes it harder to differentiate meaningful feedback from noise.

The second issue is the difficulty of understanding products from documentation. Sellers often provide manuals, brochures, or technical specification documents, but these are long, difficult to scan, and poorly integrated into the shopping experience. Users still ask simple but important questions such as what memory a device has, whether a product supports a given feature, or what options are available. If the system cannot answer clearly and accurately, many users abandon or delay purchase decisions.

BuzzCart addresses these issues through a trust-aware review system and a product-specific RAG assistant integrated into the product experience.

## 3. Motivation

### 3.1 The Trust Problem in Online Reviews

Product reviews strongly influence buying behavior, but conventional review systems are often not designed around trust. A five-star score alone does not answer important buyer questions:

- Was the reviewer a real buyer?
- Is the reviewer a stranger or someone relevant to me?
- Has the review passed moderation checks?
- Are the most useful reviews being surfaced first?

If a system cannot answer these questions, then the review layer becomes a weak decision-making tool. BuzzCart is motivated by the idea that social and transactional context can improve review credibility.

### 3.2 Social Commerce Context

BuzzCart does not treat shopping as an isolated action. It places commerce inside a social environment.

#### 3.2.1 Buyers

Buyers increasingly discover products through creators, content feeds, and peer recommendations rather than only through direct search. They also rely on trust signals, social proof, and contextual opinions before buying.

#### 3.2.2 Sellers

Sellers need more than a static product page. They need a way to publish products, attach media, connect content to products, and help users understand features quickly. They also benefit from real-time communication with interested buyers.

#### 3.2.3 Platforms

Platforms need to increase conversion while maintaining trust. This requires strong review integrity, better product education, and product discovery models that are more engaging than a plain marketplace grid.

### 3.3 Inadequacy of Existing Solutions

Most traditional ecommerce platforms solve only fragments of this problem. Review systems usually support star ratings and optional text, but not socially ranked trust-aware surfacing. Product pages may provide downloadable PDFs, but they rarely convert them into usable, conversational knowledge. Social platforms enable discovery, but often lack robust transactional trust mechanisms such as verified reviews and order-linked review eligibility.

As a result, users must assemble trust from multiple weak signals and often leave the platform to search for clarity elsewhere.

### 3.4 The Technology Opportunity

Recent improvements in full-stack web and mobile development, vector retrieval, embedding models, rerankers, and cloud-integrated storage make it possible to build a better system. A platform can now:

- link reviews to actual order history,
- rank reviews based on social proximity,
- expose buyer visibility in privacy-aware ways,
- ingest product documents,
- build per-product searchable knowledge indexes,
- answer product questions with grounded sources.

BuzzCart is built around this opportunity.

## 4. Existing Solutions and Related Work

### 4.1 Traditional Ecommerce Review Systems

Standard ecommerce review systems usually provide star ratings, text feedback, and date-based or helpfulness-based sorting. Some platforms mark verified buyers, but review ordering is still largely generic. These systems do not usually personalize trust by asking whether the reviewer belongs to the current user's known network.

BuzzCart extends the basic verified review idea by combining verified purchase, moderation status, privacy, helpful votes, and social relationship ranking.

### 4.2 Social Commerce Platforms

Social commerce platforms integrate products with creator content, live media, or short-form discovery experiences. Their strength is product visibility through engagement. However, product understanding and trust often remain secondary. A post can generate attention, but not necessarily product confidence.

BuzzCart brings product discovery and product trust closer together by connecting feed content, shop listings, real buyer data, and review prioritization.

### 4.3 Retrieval-Augmented Generation for Product Question Answering

RAG systems are increasingly used to answer questions over internal or domain-specific documents. They work by retrieving relevant chunks of source material and then generating responses grounded in that retrieved evidence. For product contexts, this is especially useful because technical details often already exist in manuals and specification sheets.

BuzzCart applies RAG in a product-specific way. Each product can have its own document index, and the chatbot answers only within that product scope. This reduces irrelevant matches and keeps the assistant tightly aligned with the product page.

### 4.4 Real-Time Commerce and Messaging Platforms

Real-time messaging is now a common expectation in commerce environments where buyers want clarification before purchasing. However, many systems still separate messaging from catalog and review workflows. BuzzCart incorporates direct messaging into the same application so social interaction, product discovery, and transaction support happen in one place.

## 5. BuzzCart System Design

### 5.1 High-Level Architecture

BuzzCart uses a layered multi-service architecture:

- Flutter frontend for the user interface
- Go backend for business logic and APIs
- PostgreSQL for relational data
- Firebase Storage for media and product documents
- Redis for temporary caching
- Python FastAPI RAG service for product-document indexing and question answering
- WebSocket channel for real-time messaging

The system separates concerns cleanly while still allowing strong integration between commerce, social interactions, and AI.

### 5.2 User Flow

At a high level, the user flow is as follows:

1. A user registers and logs in.
2. The user browses the home feed, videos, reels, or shop pages.
3. The user opens a product detail page.
4. The user sees product media, seller information, buyer previews, review previews, and trust indicators.
5. The user may ask product questions through the chatbot if a document is available.
6. The user adds the product to cart and completes checkout.
7. After purchase, the user becomes eligible to leave a verified review.
8. Other users later see that review in socially relevant order.

### 5.3 Trust-Centered Review Flow

The review subsystem is central to the system design.

1. The buyer completes an order.
2. The order and order items are stored in the database.
3. When the user attempts to review a product, the backend checks whether the product exists and whether the user has purchased it.
4. If the purchase exists, the review is stored with `is_verified_purchase = true`.
5. Ranked review retrieval orders public approved reviews using social relationship weights and helpful votes.
6. The frontend surfaces verified purchase badges and connection signals to make trust visible to end users.

### 5.4 Database Schema

The schema includes data structures for:

- users and profiles,
- products and product images,
- carts, orders, and order items,
- product ratings and helpful votes,
- content items and product-content linking,
- posts and fan-out feed structures,
- conversations and messages,
- privacy, moderation, and visibility settings.

This schema is relational and strongly aligned with the application's business rules.

### 5.5 API Design

The backend exposes route groups for:

- authentication,
- users,
- products,
- reviews,
- videos,
- reels,
- cart,
- checkout,
- uploads,
- feed,
- posts,
- search,
- messages.

The chatbot service exposes its own API for:

- health checks,
- asking product-document questions,
- syncing product documents,
- uploading product documents,
- checking document status,
- deleting document indexes.

### 5.6 Key Design Decisions

Several design choices define the system:

- reviews are linked to real purchase history rather than open submission,
- review ordering is socially aware rather than only date-based,
- RAG indexes are scoped per product rather than global,
- media and documents are externalized to storage instead of the relational database,
- the platform supports both content-first discovery and product-first shopping,
- messaging is built into the product ecosystem rather than outsourced.

## 6. Implementation

### 6.1 Frontend: Flutter Application

The frontend is built with Flutter and uses `provider` for state management and `go_router` for navigation. It supports responsive rendering through a desktop sidebar layout and a mobile bottom-navigation layout. The application is divided into major screens such as home, shop, reels, videos, profile, cart, messages, upload, and settings.

#### 6.1.1 Authentication Flow

The app initializes an authentication provider early and uses router-level redirects to manage access. Splash, login, and signup routes exist as public entry points. Once the user's auth state resolves, protected routes become accessible through a stateful shell with persistent navigation branches.

This design makes the user experience smooth while keeping protected pages gated behind authentication.

#### 6.1.2 Product Discovery and Shop Experience

The shop page supports both product listing and product detail views. Product cards show price, discount information, seller or brand information, and social preview widgets. Product detail pages combine media galleries, cart controls, buyer visibility, review visibility, and chatbot access. The home page mixes product rails, posts, videos, and reels to create a discovery-oriented feed rather than a pure catalog.

This hybrid design is one of BuzzCart's strongest differentiators because it reflects how users actually discover products in social environments.

#### 6.1.3 Review and Buyer Visibility Interfaces

The UI provides:

- product review sheets,
- write or edit review flows,
- buyer preview and buyer list sheets,
- badges such as `Verified Purchase` and `Connection`.

Reviews are not just text blocks. They are presented as social trust objects. Buyers for a product can also be surfaced in a privacy-aware way, which reinforces trust and social proof.

#### 6.1.4 Product Document Chat Experience

The frontend includes a chatbot service client that can:

- ask a question about a product document,
- trigger a document sync,
- check the document's indexing status,
- delete a product's document index.

This makes the AI assistant part of the product workflow, not a separate experimental feature.

### 6.2 Backend: Go Server

The backend is implemented with Go and Gin. It loads environment configuration, connects to PostgreSQL, initializes Redis, initializes storage, exposes health checks, and registers all route groups under a main API router.

#### 6.2.1 Deployment Environment

The project includes Docker Compose definitions for:

- backend,
- frontend,
- chatbot,
- Redis,
- Ollama,
- Cloud SQL proxy.

This indicates a production-minded deployment design even if the exact hosting environment may vary between local and cloud usage.

#### 6.2.2 Core API Modules

The backend implements several domain-specific handler groups:

- auth handlers for login, registration, and profile updates,
- product handlers for creation, updates, listing, reviews, and buyers,
- checkout handlers for order creation and purchase retrieval,
- feed and post handlers for social content,
- upload handlers for image, video, avatar, and product-document uploads,
- message handlers for conversations and message delivery.

This modular breakdown improves maintainability and aligns code structure with business capabilities.

#### 6.2.3 Review Ranking and Verified Purchase Enforcement

This is the most important backend feature in the project.

When a user creates a review:

- the backend first verifies the product exists,
- it checks whether the user already reviewed it,
- it then checks whether the user has a completed or delivered order containing that product,
- only then does it allow review creation,
- the created review is stored as a verified purchase review.

When ranked reviews are fetched for a logged-in user, the backend computes relationship weight based on follow relationships:

- author follows current user: highest relevance,
- mutual follow: high relevance,
- current user follows author: next relevance,
- otherwise: public relevance only.

The results are then ordered by relationship weight, helpful count, and recency. This is a direct implementation of the idea that reviews should come from known people first.

#### 6.2.4 Real-Time Messaging Pipeline

The system exposes a WebSocket endpoint for messages. On the frontend, the message socket service manages:

- connection setup,
- reconnection attempts,
- active conversation handling,
- typing events,
- real-time event streaming.

This makes product-related conversation immediate and supports stronger buyer-seller engagement.

### 6.3 Storage, Database, and Cache Integration

#### 6.3.1 PostgreSQL

PostgreSQL acts as the main transactional store. It holds user data, product data, orders, reviews, messages, posts, content relationships, and visibility state. The schema design supports both transactional commerce and social interactions in the same relational system.

#### 6.3.2 Firebase Storage

Firebase Storage is used for user avatars, product images, uploaded content media, and product documents. This keeps large binary assets out of the relational database and gives the system a scalable media storage model.

#### 6.3.3 Redis

Redis is used primarily as a cache. One clear use case is the short-lived caching of ranked product reviews, reducing repeated database work for the same product-review ordering queries.

### 6.4 Product Document RAG Service

The chatbot service is implemented separately in Python with FastAPI.

#### 6.4.1 Document Ingestion and Indexing

The service can accept product documents through direct upload or by syncing from a document URL. A PDF is downloaded or received, parsed page by page, normalized, chunked by token count, and written into a product-specific vector store with manifest metadata such as page count, source name, and update timestamp.

This design makes the document pipeline maintainable and allows index refresh when a product document changes.

#### 6.4.2 Hybrid Retrieval and Reranking

The RAG service uses:

- embedding-based dense retrieval,
- lexical scoring,
- candidate expansion with neighboring chunks,
- cross-encoder reranking.

This layered retrieval strategy is more reliable than plain nearest-neighbor search because it captures both semantic and term-level relevance.

#### 6.4.3 Grounded Response Generation

The response engine attempts structured document fact extraction, direct answer extraction, section-based extraction, and retrieved-evidence synthesis. The returned response includes:

- answer text,
- source page,
- source chunk,
- confidence level.

This is important because the assistant is designed to reduce hallucination and remain grounded in product evidence.

## 7. Evaluation

### 7.1 Functional Coverage

From the codebase and route structure, the project functionally covers:

- user authentication and profile handling,
- seller product publishing,
- product browsing and detail views,
- cart and checkout processing,
- verified review creation,
- review helpful voting,
- socially ranked review retrieval,
- buyer visibility,
- content-based product discovery through posts, videos, and reels,
- real-time messaging,
- product-document upload and indexing,
- AI-powered product question answering.

This is broad coverage for a major project and shows that BuzzCart is not a single-feature prototype.

### 7.2 Results

The strongest project outcomes are architectural and functional:

- The review system is tied to real order history, which improves authenticity.
- The product page presents trust signals in a user-facing way through verified badges, connection badges, review previews, and buyer previews.
- The platform supports both direct shop exploration and social-feed discovery.
- The RAG service converts passive product PDFs into an interactive product assistance layer.
- The backend is modular and production-oriented, with clear route grouping and service separation.

In particular, the two core project goals are successfully represented in the implementation:

1. reviews are made more trustworthy because they come from real buyers and are ranked using known-person social context,
2. a RAG assistant helps users understand product details by answering from product documents instead of from unsupported generic responses.

### 7.3 Performance and Scalability Considerations

The present codebase includes several design choices that support scale and maintainability:

- Redis caching for repeated review reads,
- product-scoped vector indexes rather than one large shared index,
- externalized media storage,
- Dockerized service boundaries,
- token-based document chunking for more stable retrieval behavior,
- reranking to improve answer quality without requiring a large monolithic model.

A full quantitative benchmark is not included in the current repository materials, so this report does not invent latency numbers. However, the system structure indicates a reasonable path toward scalable deployment.

## 8. Conclusion and Future Work

BuzzCart demonstrates a strong and relevant application of full-stack engineering to a modern commerce problem. It is not merely an online store, and it is not merely a social feed. Instead, it combines commerce, trust, social proof, and AI assistance into a single platform.

The central contribution of the project is that it treats trust and understanding as first-class product requirements. Review systems are made stronger by restricting review eligibility to actual buyers, by surfacing verified purchase badges, and by ranking reviews using known social relationships. Product understanding is improved by attaching official documents to products and turning those documents into grounded conversational knowledge through a dedicated RAG service.

Future work can expand the system in several directions:

- integration with a real payment gateway,
- recommendation systems based on user behavior,
- moderation dashboards and analytics,
- stronger seller analytics tools,
- richer chatbot interfaces including follow-up conversational memory,
- multilingual document ingestion and answer generation,
- deeper trust scoring using review quality and buyer reputation patterns.

Overall, BuzzCart is a well-structured major project that solves practical problems in social commerce and demonstrates strong integration across frontend, backend, storage, messaging, and AI subsystems.

## References

1. BuzzCart source code and project files, including frontend, backend, chatbot, database migrations, and Docker configuration.
2. Flutter documentation: https://docs.flutter.dev/
3. Go documentation: https://go.dev/doc/
4. Gin Web Framework documentation: https://gin-gonic.com/
5. PostgreSQL documentation: https://www.postgresql.org/docs/
6. Redis documentation: https://redis.io/docs/
7. FastAPI documentation: https://fastapi.tiangolo.com/
8. Firebase documentation: https://firebase.google.com/docs
9. FAISS documentation: https://faiss.ai/
10. Sentence Transformers documentation: https://www.sbert.net/
