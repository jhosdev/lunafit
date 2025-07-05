# Fitness Tracker - Serverless Architecture & Domain Design

## Overview

This project demonstrates a real-world serverless fitness tracking application built with Rust, AWS Lambda, and DynamoDB. It implements Domain-Driven Design (DDD), Test-Driven Development (TDD), and follows idiomatic Rust practices for backend development.

## Architecture Philosophy

### Serverless-First Design
- **Event-Driven Architecture**: Each domain publishes events that other domains consume
- **Immutable Event Log**: All changes are captured as events for complete audit trails
- **CQRS Pattern**: Separate write (command) and read (query) models
- **Eventual Consistency**: Domains are eventually consistent via event propagation

### Technology Stack
- **Runtime**: Rust with AWS Lambda
- **Database**: DynamoDB (single-table design per domain)
- **Event Bus**: SQS FIFO queues for reliable event ordering
- **API**: API Gateway with custom authorizers
- **Infrastructure**: Terraform for IaC

## Domain Architecture

We've identified **6 bounded contexts** that reflect the real-world fitness tracking workflow:

### 1. Identity Domain
**Purpose**: User authentication and basic identity management

**Responsibilities**:
- User registration and authentication
- Identity verification
- Basic user metadata (creation time, status)

**Events Published**:
- `UserRegistered`
- `UserActivated` 
- `UserDeactivated`

### 2. Profile Domain  
**Purpose**: User profile information and fitness goals

**Responsibilities**:
- Personal information (name, DOB, preferences)
- Fitness goals and targets
- Profile updates and history

**Events Published**:
- `ProfileCreated`
- `ProfileUpdated`
- `GoalsChanged`

### 3. Planning Domain
**Purpose**: Template definitions for workouts, meals, and supplements

**Responsibilities**:
- Workout routine templates (exercises, sets, reps, rest periods)
- Meal plan templates (ingredients, portions, timing)
- Supplement plan templates (dosage, frequency)
- Template versioning and evolution

**Events Published**:
- `WorkoutTemplateCreated`
- `WorkoutTemplateUpdated`
- `MealPlanCreated`
- `SupplementPlanCreated`

### 4. Scheduling Domain
**Purpose**: Assigns plans to specific days and manages schedule changes

**Responsibilities**:
- Weekly schedule management
- Plan-to-day assignments
- Schedule change tracking and preview
- Conflict resolution

**Events Published**:
- `ScheduleCreated`
- `ScheduleUpdated`
- `DayPlanChanged`

**Events Consumed**:
- `WorkoutTemplateUpdated` (to update schedules using that template)
- `MealPlanUpdated`

### 5. Execution Domain ⭐ (NEW)
**Purpose**: Records what actually happened during workouts, meals, and supplements

**Responsibilities**:
- Workout execution logs (actual weights, reps, rest times)
- Meal consumption logs (what was eaten, when, portions)
- Supplement intake logs (what was taken, dosage, timing)
- Real-time progress capture during activities

**Events Published**:
- `WorkoutExecuted`
- `MealConsumed`
- `SupplementTaken`
- `ProgressMilestoneReached`

### 6. Analytics Domain
**Purpose**: Computes progress metrics and provides insights

**Responsibilities**:
- Progress calculations (strength gains, consistency metrics)
- Trend analysis (weekly/monthly progress)
- Performance comparisons (planned vs actual)
- Recommendation generation

**Events Published**:
- `ProgressCalculated`
- `TrendAnalyzed`
- `RecommendationGenerated`

**Events Consumed**:
- `WorkoutExecuted`
- `MealConsumed`
- `SupplementTaken`

## Data Models & Event Sourcing

### DynamoDB Schema Patterns

Each domain uses a single table with event sourcing:

```rust
// Common event structure
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DomainEvent {
    pub aggregate_id: String,
    pub event_type: String,
    pub event_version: u32,
    pub event_data: serde_json::Value,
    pub timestamp: DateTime<Utc>,
    pub correlation_id: Option<String>,
}

// DynamoDB structure
PK: DOMAIN#{domain_name}#{aggregate_id}
SK: EVENT#{timestamp}#{event_type}
```

### Example: Planning Domain Events

```rust
#[derive(Serialize, Deserialize, Debug)]
pub enum PlanningEvent {
    WorkoutTemplateCreated {
        template_id: String,
        name: String,
        exercises: Vec<Exercise>,
        estimated_duration_minutes: u32,
    },
    WorkoutTemplateUpdated {
        template_id: String,
        changes: WorkoutChanges,
        previous_version: u32,
    },
    ExerciseProgressionUpdated {
        template_id: String,
        exercise_id: String,
        old_weight: f32,
        new_weight: f32,
        progression_reason: ProgressionReason,
    },
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Exercise {
    pub id: String,
    pub name: String,
    pub sets: u32,
    pub reps: u32,
    pub weight_kg: f32,
    pub rest_seconds: u32,
    pub notes: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub enum ProgressionReason {
    CompletedAllReps,
    UserRequested,
    AnalyticsRecommendation,
}
```

### Example: Execution Domain Events

```rust
#[derive(Serialize, Deserialize, Debug)]
pub enum ExecutionEvent {
    WorkoutStarted {
        workout_id: String,
        template_id: String,
        planned_exercises: Vec<Exercise>,
        started_at: DateTime<Utc>,
    },
    ExerciseCompleted {
        workout_id: String,
        exercise_id: String,
        actual_sets: u32,
        actual_reps: Vec<u32>, // per set
        actual_weight_kg: f32,
        actual_rest_seconds: Vec<u32>, // per set
        completed_at: DateTime<Utc>,
    },
    WorkoutCompleted {
        workout_id: String,
        total_duration_minutes: u32,
        completed_exercises: u32,
        skipped_exercises: u32,
        completed_at: DateTime<Utc>,
    },
    ProgressMilestoneReached {
        workout_id: String,
        exercise_id: String,
        milestone_type: MilestoneType,
        previous_value: f32,
        new_value: f32,
    },
}

#[derive(Serialize, Deserialize, Debug)]
pub enum MilestoneType {
    WeightIncrease,
    NewPersonalRecord,
    ConsistencyStreak,
}
```

## Rust Project Structure

```
fitness-tracker/
├── Cargo.toml
├── crates/
│   ├── shared/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── events/
│   │       ├── error.rs
│   │       └── dynamodb/
│   ├── identity/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── domain/
│   │       ├── handlers/
│   │       ├── repository/
│   │       └── events/
│   ├── planning/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── domain/
│   │       │   ├── mod.rs
│   │       │   ├── workout_template.rs
│   │       │   ├── meal_plan.rs
│   │       │   └── events.rs
│   │       ├── handlers/
│   │       │   ├── mod.rs
│   │       │   ├── http.rs
│   │       │   └── event.rs
│   │       └── repository/
│   ├── execution/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── domain/
│   │       │   ├── mod.rs
│   │       │   ├── workout_execution.rs
│   │       │   ├── meal_consumption.rs
│   │       │   └── events.rs
│   │       ├── handlers/
│   │       └── repository/
│   └── analytics/
│       ├── Cargo.toml
│       └── src/
│           ├── lib.rs
│           ├── domain/
│           ├── handlers/
│           └── repository/
├── infrastructure/
│   ├── terraform/
│   │   ├── main.tf
│   │   ├── dynamodb.tf
│   │   ├── lambda.tf
│   │   ├── api-gateway.tf
│   │   └── sqs.tf
│   └── scripts/
└── docs/
    ├── architecture.md
    ├── domain-design.md
    └── deployment.md
```

## Rust Best Practices Implementation

### 1. Error Handling
```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DomainError {
    #[error("Aggregate not found: {id}")]
    AggregateNotFound { id: String },
    
    #[error("Invalid event sequence: expected {expected}, got {actual}")]
    InvalidEventSequence { expected: u32, actual: u32 },
    
    #[error("Business rule violation: {message}")]
    BusinessRuleViolation { message: String },
    
    #[error("Repository error: {0}")]
    Repository(#[from] aws_sdk_dynamodb::Error),
}

pub type DomainResult<T> = Result<T, DomainError>;
```

### 2. Domain Aggregates
```rust
use uuid::Uuid;
use chrono::{DateTime, Utc};

#[derive(Debug, Clone)]
pub struct WorkoutTemplate {
    id: String,
    name: String,
    exercises: Vec<Exercise>,
    version: u32,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl WorkoutTemplate {
    pub fn new(name: String, exercises: Vec<Exercise>) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name,
            exercises,
            version: 1,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }
    }
    
    pub fn update_exercise_weight(
        &mut self, 
        exercise_id: &str, 
        new_weight: f32
    ) -> DomainResult<PlanningEvent> {
        let exercise = self.exercises
            .iter_mut()
            .find(|e| e.id == exercise_id)
            .ok_or(DomainError::BusinessRuleViolation {
                message: format!("Exercise {} not found", exercise_id)
            })?;
            
        let old_weight = exercise.weight_kg;
        exercise.weight_kg = new_weight;
        self.version += 1;
        self.updated_at = Utc::now();
        
        Ok(PlanningEvent::ExerciseProgressionUpdated {
            template_id: self.id.clone(),
            exercise_id: exercise_id.to_string(),
            old_weight,
            new_weight,
            progression_reason: ProgressionReason::UserRequested,
        })
    }
}
```

### 3. Repository Pattern
```rust
use async_trait::async_trait;
use aws_sdk_dynamodb::Client;

#[async_trait]
pub trait WorkoutTemplateRepository {
    async fn save(&self, template: &WorkoutTemplate) -> DomainResult<()>;
    async fn find_by_id(&self, id: &str) -> DomainResult<Option<WorkoutTemplate>>;
    async fn save_event(&self, event: &DomainEvent) -> DomainResult<()>;
    async fn get_events(&self, aggregate_id: &str) -> DomainResult<Vec<DomainEvent>>;
}

pub struct DynamoWorkoutTemplateRepository {
    client: Client,
    table_name: String,
}

#[async_trait]
impl WorkoutTemplateRepository for DynamoWorkoutTemplateRepository {
    async fn save_event(&self, event: &DomainEvent) -> DomainResult<()> {
        let item = serde_dynamo::to_item(event)?;
        
        self.client
            .put_item()
            .table_name(&self.table_name)
            .set_item(Some(item))
            .send()
            .await?;
            
        Ok(())
    }
    
    async fn get_events(&self, aggregate_id: &str) -> DomainResult<Vec<DomainEvent>> {
        let response = self.client
            .query()
            .table_name(&self.table_name)
            .key_condition_expression("PK = :pk")
            .expression_attribute_values(":pk", AttributeValue::S(
                format!("PLANNING#{}", aggregate_id)
            ))
            .send()
            .await?;
            
        let events = response.items
            .unwrap_or_default()
            .into_iter()
            .map(|item| serde_dynamo::from_item(item))
            .collect::<Result<Vec<_>, _>>()?;
            
        Ok(events)
    }
}
```

### 4. Lambda Handlers
```rust
use lambda_runtime::{run, service_fn, LambdaEvent, Error};
use serde::{Deserialize, Serialize};
use tracing::{info, instrument};

#[derive(Deserialize)]
struct CreateWorkoutRequest {
    name: String,
    exercises: Vec<Exercise>,
}

#[derive(Serialize)]
struct CreateWorkoutResponse {
    id: String,
    version: u32,
}

#[instrument(skip(event))]
async fn create_workout_handler(
    event: LambdaEvent<CreateWorkoutRequest>
) -> Result<CreateWorkoutResponse, Error> {
    info!("Creating workout template: {}", event.payload.name);
    
    let template = WorkoutTemplate::new(
        event.payload.name,
        event.payload.exercises
    );
    
    let repository = DynamoWorkoutTemplateRepository::new().await?;
    
    // Save the aggregate
    repository.save(&template).await?;
    
    // Publish event
    let event = PlanningEvent::WorkoutTemplateCreated {
        template_id: template.id.clone(),
        name: template.name.clone(),
        exercises: template.exercises.clone(),
        estimated_duration_minutes: template.estimated_duration(),
    };
    
    publish_event("planning", &event).await?;
    
    Ok(CreateWorkoutResponse {
        id: template.id,
        version: template.version,
    })
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();
        
    run(service_fn(create_workout_handler)).await
}
```

## Use Case Implementation

### 1. Gym Schedule with Custom Rest Times
```rust
// Planning Domain - Create workout template
let monday_workout = WorkoutTemplate::new(
    "Monday Upper Body".to_string(),
    vec![
        Exercise {
            id: "bench-press".to_string(),
            name: "Bench Press".to_string(),
            sets: 3,
            reps: 8,
            weight_kg: 40.0,
            rest_seconds: 90,
            notes: None,
        },
        Exercise {
            id: "shoulder-press".to_string(),
            name: "Shoulder Press".to_string(),
            sets: 3,
            reps: 10,
            weight_kg: 25.0,
            rest_seconds: 60,
            notes: None,
        },
    ]
);

// Scheduling Domain - Assign to Monday
schedule_service.assign_plan_to_day(
    "MON", 
    &monday_workout.id, 
    monday_workout.version
).await?;
```

### 2. Progress Tracking (40kg → 50kg)
```rust
// Execution Domain - Log actual workout
let workout_execution = WorkoutExecution::start(
    &monday_workout.id,
    &monday_workout
).await?;

// User completes bench press with increased weight
workout_execution.complete_exercise(
    "bench-press",
    3, // actual sets
    vec![8, 8, 8], // actual reps per set
    50.0, // new weight!
    vec![90, 95, 100], // actual rest times
).await?;

// This triggers a ProgressMilestoneReached event
// Analytics Domain picks this up and:
// 1. Updates progress metrics
// 2. Suggests updating the template
```

### 3. Schedule Change Preview
```rust
// Planning Domain - Update workout duration
let updated_template = planning_service
    .update_workout_duration(&monday_workout.id, 45)
    .await?;

// Scheduling Domain - Preview impact
let schedule_preview = scheduling_service
    .preview_template_update(&updated_template.id)
    .await?;

// Returns: "This will affect Monday's workout (30min → 45min)"
```

## Testing Strategy

### Unit Tests
```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_workout_template_creation() {
        let template = WorkoutTemplate::new(
            "Test Workout".to_string(),
            vec![create_test_exercise()],
        );
        
        assert_eq!(template.name, "Test Workout");
        assert_eq!(template.version, 1);
        assert!(!template.id.is_empty());
    }
    
    #[test]
    fn test_exercise_weight_progression() {
        let mut template = create_test_template();
        
        let result = template.update_exercise_weight("bench-press", 50.0);
        
        assert!(result.is_ok());
        assert_eq!(template.version, 2);
        
        if let PlanningEvent::ExerciseProgressionUpdated { 
            old_weight, new_weight, .. 
        } = result.unwrap() {
            assert_eq!(old_weight, 40.0);
            assert_eq!(new_weight, 50.0);
        }
    }
}
```

### Integration Tests
```rust
#[tokio::test]
async fn test_workout_execution_flow() {
    let repository = MockWorkoutTemplateRepository::new();
    let event_bus = MockEventBus::new();
    
    let service = WorkoutService::new(repository, event_bus);
    
    // Create template
    let template = service.create_workout_template(
        "Test Workout".to_string(),
        vec![create_test_exercise()],
    ).await.unwrap();
    
    // Execute workout
    let execution = service.start_workout_execution(&template.id)
        .await.unwrap();
    
    // Verify events were published
    let events = event_bus.get_published_events().await;
    assert_eq!(events.len(), 2); // Created + Started
}
```

## Event Flow Examples

### Workout Progression Flow
```
1. User completes workout with increased weight
   → ExecutionEvent::ExerciseCompleted (weight: 50kg)
   
2. Analytics Domain processes event
   → Detects progression milestone
   → PublishEvent::ProgressMilestoneReached
   
3. Planning Domain receives milestone event
   → Updates template with new weight
   → PublishEvent::WorkoutTemplateUpdated
   
4. Scheduling Domain receives template update
   → Updates affected schedule entries
   → PublishEvent::ScheduleUpdated
```

### Schedule Change Preview Flow
```
1. User requests workout duration change
   → Planning Domain creates new template version
   
2. Scheduling Domain calculates impact
   → Queries all schedules using this template
   → Returns preview of affected days
   
3. User confirms change
   → Template version is saved
   → Schedule entries are updated
   → Events are published
```

## Deployment & Infrastructure

The project uses Terraform for infrastructure as code, with each domain deployed as separate Lambda functions connected via SQS FIFO queues for reliable event ordering.

### Key Infrastructure Components:
- **DynamoDB**: One table per domain with event sourcing
- **SQS FIFO**: Event buses between domains  
- **Lambda**: Rust-based functions for each domain
- **API Gateway**: HTTP endpoints with custom authorizers
- **CloudWatch**: Logging and monitoring

This architecture provides a production-ready, scalable foundation for fitness tracking while demonstrating modern Rust backend development practices.