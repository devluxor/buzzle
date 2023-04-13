-- LOAD_PRIVATE_MESSAGES
  SELECT 
    MAX(private_messages.created_on), 
    private_messages.sender_id,
    private_messages.receiver_id
  FROM private_messages
  JOIN users ON private_messages.sender_id = users.id
  WHERE sender_id = 1 OR receiver_id = 1
  GROUP BY private_messages.sender_id, receiver_id;
