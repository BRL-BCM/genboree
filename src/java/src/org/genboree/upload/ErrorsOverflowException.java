package org.genboree.upload;

/**
 * This exception is thrown when an attempt is made to add an error message to a full error list.
 *
 * @author                  Ming-Te Cheng
 * @version                 1.0 
 * @since                   1.4.2
 */
public class ErrorsOverflowException extends Exception {

    /**
     * Constructs a new instance of ErrorsOverflowException.
     */
    public ErrorsOverflowException() {}

}
